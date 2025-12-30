using System;
using System.Web;
using System.Web.UI;
using Oracle.DataAccess.Client;
using System.Data;
using Website._sys;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Drawing.Imaging;
using System.Drawing;
using static System.Net.Mime.MediaTypeNames;

namespace Website
{
    public partial class Paginas : BasePage
    {
        /// <summary>
        /// Al cargarse una página, recoje las variables de session, los queryString, el form.request, el files.request 
        /// y con esta información ejecuta el framework Quimera para que genere una página dinámica
        /// </summary>
        /// <param name="sender">Parámetro standard de .net para este tipo de evento</param>
        /// <param name="e">Parámetro standard de .net para este tipo de evento</param>
        protected void Page_Load(object sender, EventArgs e)
        {
            String htmlCode;
            string jsCode = "";
            try
            {
                if (string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_usuario"] as string)) {
                    Web.Entrar();
                }

                if ((
                 string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_inventario"] as string)
                 &&
                 string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["menu"] as string)
                )) {
                    Response.Redirect("/NoBienvenido.aspx");
                }
                else 
                {
                    string xmlData = "<?xml version=\"1.0\"?><fields>"
                               + "<field><key>ID_USUARIO</key><val>" + Session["id_usuario"] + "</val></field>"
                               + "<field><key>ID_INVENTARIO</key><val>" + Session["id_inventario"] + "</val></field>";

                    if (!Page.IsPostBack)
                    {
                        //es la primera vez que entra a esta página en esta sesion

                        // generar un string de sesion al azar
                        div_sesion.InnerText = Web.RandomString(50);

                        //leer los querystring s de pagina y registro
                        div_pagina.InnerText = Request.QueryString["pag"];
                        if (Request.QueryString["reg"] != null)
                        {
                            xmlData = xmlData + "<field><key>reg</key><val>" + Request.QueryString["reg"] + "</val></field>";
                        }
                        if (Request.QueryString["mst"] != null)
                        {
                            xmlData = xmlData + "<field><key>LOV_MAESTRO</key><val>" + Request.QueryString["mst"] + "</val></field>";
                        }

                        DB.EjecutarProcedimiento("inv_db.man_mantenimientos_pkg.sesion_iniciar", new Object[][] {
                        new Object[] {"p_id_sesion", OracleDbType.Varchar2,100, ParameterDirection.Input,  div_sesion.InnerText}
                    });
                    }

                    // cargar en un xml todos los elementos recibidos en el form object y del file object
                    foreach (string key in Request.Form)
                    {
                        if (!key.Contains("VIEWSTATE"))
                        {
                            xmlData += "<field>";
                            xmlData += "<key>" + key + "</key>";
                            xmlData += "<val>" + Web.HtmlEscape(Request.Form[key]) + "</val>";
                            xmlData += "</field>";
                        }
                    }
                    xmlData += "</fields>";

                    // cargar el contenido de los archivos cargados en la sesion del usuario
                    System.Web.HttpFileCollection files = Request.Files;
                    string[] fieldNames = files.AllKeys;
                    for (int i = 0; i < fieldNames.Length; ++i)
                    {
                        string inputName = fieldNames[i]; //The 'name' attribute of the html form
                        System.Web.HttpPostedFile file = files[i];
                        int len = files[i].ContentLength; //The length of the file
                        if (len > 0)
                        {
                            System.IO.Stream stream = files[i].InputStream; //The actual file data
                            BinaryReader br = new BinaryReader(stream);
                            byte[] binaryData = br.ReadBytes((int)len);

                            // si es un jpg de mas de 1mb, hacerle resize
                            if (files[i].FileName.ToLower().EndsWith(".jpg") || files[i].FileName.ToLower().EndsWith(".jpeg"))
                            {
                                try
                                {
                                    binaryData = Web.ReduceImageSize(binaryData, 35);
                                }
                                catch
                                {
                                    // dió error al reducir el tamaño, dejarlo como está
                                }
                            }

                            DB.EjecutarProcedimiento("inv_db.man_mantenimientos_pkg.sesion_guardar_documento", new Object[][] {
                            new Object[] {"p_id_sesion",           OracleDbType.Varchar2, 100, ParameterDirection.Input, div_sesion.InnerText},
                            new Object[] {"p_id_usuario",          OracleDbType.Varchar2, 100, ParameterDirection.Input, Session["id_usuario"]},
                            new Object[] {"p_id_pagina",           OracleDbType.Varchar2, 500, ParameterDirection.Input, div_pagina.InnerText},
                            new Object[] {"p_llave",               OracleDbType.Varchar2, 100, ParameterDirection.Input, inputName},
                            new Object[] {"p_filename",            OracleDbType.Varchar2,2000, ParameterDirection.Input, files[i].FileName},
                            new Object[] {"p_documento",           OracleDbType.Blob,          ParameterDirection.Input, binaryData}
                        });
                        }
                    }


                    // si en el formulario existe alguno de los botones de impresión o exportar hay que hacer ejecutar a inv_db.man_mantenimientos_pkg.preparar para que genere el reporte
                    // o exportacion a excell, mas adelante se ejecutará de nuevo para que genere la página actual (que ya no tendrá en el formulario los botones de imprimir/exportar)
                    if (xmlData.Contains("BTN_IMPRIMIR")
                    || xmlData.Contains("BTN_EXPORTAR")
                    || xmlData.Contains("BTN_REPORTE_")
                    || xmlData.Contains("BTN_DOWNLOAD"))
                    {
                        htmlCode = DB.EjecutarProcedimientoDevuelveClob("inv_db.man_mantenimientos_pkg.preparar", "p_resultado", new Object[][] {
                        new Object[] {"p_id_pagina",          OracleDbType.Varchar2,  500, ParameterDirection.InputOutput, div_pagina.InnerText},
                        new Object[] {"p_id_sesion",          OracleDbType.Varchar2,  100, ParameterDirection.Input,       div_sesion.InnerText},
                        new Object[] {"p_id_usuario_procesa", OracleDbType.Varchar2,  100, ParameterDirection.Input,       Session["id_usuario"]},
                        new Object[] {"p_formulario",         OracleDbType.Varchar2,32000, ParameterDirection.Input,       xmlData},
                        new Object[] {"p_resultado",          OracleDbType.Clob,           ParameterDirection.InputOutput, null }
                    });
                        if (xmlData.Contains("BTN_IMPRIMIR") || xmlData.Contains("BTN_REPORTE_"))
                        {
                            //este es el javascript que imprime
                            jsCode += "<script type=\"text/javascript\">\n"
                                    + "function imprimir() {\n"
                                    + "var doc = document.getElementById('frame_impresion').contentWindow.document;"
                                    + " doc.open();"
                                    + " doc.write('" + htmlCode.Replace("\r", "").Replace("\n", "").Replace("'", "&apos;") + "');"
                                    + " doc.close();"
                                    + " document.getElementById('frame_impresion').contentWindow.print();"
                                    + "}\n"
                                    + "window.addEventListener('DOMContentLoaded', (event) => {imprimir();});"
                                    + "</script>\n";
                            //ya que se imprimió, quitar del formulario los botones de imprimir para que no los encuentre de nuevo en el proximo postback
                            xmlData = xmlData.Replace("BTN_IMPRIMIR", "************");
                            xmlData = xmlData.Replace("BTN_REPORTE_", "************");
                        }
                        else if (xmlData.Contains("BTN_EXPORTAR"))
                        {
                            //encontrar el titulo del reporte para usarlo como nombre del archivo a descargar
                            int pFrom = htmlCode.IndexOf("Reporte de ");
                            int pTo = htmlCode.IndexOf("</div>");
                            String filename;
                            if (pFrom > 0 && pTo > 0)
                            {
                                filename = htmlCode.Substring(pFrom, pTo - pFrom) + ".xls";
                            } else
                            {
                                filename = "data.xls";
                            }

                            Response.Clear();
                            Response.ContentType = "application/vnd.ms-excel";
                            Response.AddHeader("Content-Disposition", "attachment;filename=" + filename);
                            this.EnableViewState = false;
                            Response.Write(Web.HtmlEncode(htmlCode));
                            Response.End();
                            //ya que se exportó, quitar del formulario el boton de exportar para que no lo encuentre de nuevo en el proximo postback
                            xmlData = xmlData.Replace("BTN_EXPORTAR", "************");
                        }
                        else if (xmlData.Contains("BTN_DOWNLOAD"))
                        {
                            string filename = htmlCode.Split(',')[2].Replace("filename=", "")
                                                                    .Replace("\\", "_")
                                                                    .Replace("/", "_")
                                                                    .Replace(":", "_")
                                                                    .Replace("*", "_")
                                                                    .Replace("?", "_")
                                                                    .Replace("\"", "_")
                                                                    .Replace("<", "_")
                                                                    .Replace(">", "_")
                                                                    .Replace("|", "_");
                            string ext = htmlCode.Split(',')[3].Replace("ext=", "");
                            if (ext.Length > 0)
                            {
                                ext = "." + ext;
                            }
                            string type = htmlCode.Split(',')[4].Replace("type=", "");
                            string contents = htmlCode.Split(',')[5];

                            byte[] blobBytes = Convert.FromBase64String(contents);

                            Response.Clear();
                            Response.ContentType = type;
                            Response.AddHeader("Content-Disposition", "attachment;filename=" + filename + ext);
                            this.EnableViewState = false;
                            Response.BinaryWrite(blobBytes);
                            Response.End();
                            xmlData = xmlData.Replace("BTN_DOWNLOAD", "************");
                        }
                    }

                    //ejecutar el procedimiento que genera la pagina actual
                    Dictionary<String, String> parametros = DB.EjecutarProcedimientoDevuelveParametros("inv_db.man_mantenimientos_pkg.preparar", new Object[][] {
                    new Object[] {"p_id_pagina",          OracleDbType.Varchar2,  500, ParameterDirection.InputOutput, div_pagina.InnerText},
                    new Object[] {"p_id_sesion",          OracleDbType.Varchar2,  100, ParameterDirection.Input,       div_sesion.InnerText},
                    new Object[] {"p_id_usuario_procesa", OracleDbType.Varchar2,  100, ParameterDirection.Input,       Session["id_usuario"]},
                    new Object[] {"p_formulario",         OracleDbType.Varchar2,32000, ParameterDirection.Input,       xmlData},
                    new Object[] {"p_resultado",          OracleDbType.Clob,           ParameterDirection.InputOutput, null }
                });

                    div_pagina.InnerText = parametros["p_id_pagina"];
                    String resultado = parametros["p_resultado"];

                    div_contenido.InnerHtml = resultado + jsCode;
                }
            } catch (Exception ex) {
                Random r = new Random();  
                int num=r.Next();
                String log =
                    "Error Id:" + num.ToString() + Environment.NewLine +
                    "User:" + Session["id_usuario"] + Environment.NewLine +
                    "Date:" + DateTime.Now.ToString() + Environment.NewLine +
                    "Page:" + Request.QueryString["pagina"] + "/" + Session["id_pagina"] + Environment.NewLine +
                    "Message :" + ex.Message + Environment.NewLine +
                    "StackTrace :" + ex.StackTrace + Environment.NewLine +
                    Environment.NewLine;

                File.AppendAllText(Server.MapPath(Session["logfile"].ToString()), log);
                div_contenido.InnerHtml = 
                    "<div id=\"msg_error\">Ha ocurrido un error, favor contactar a nuestra mesa de ayuda." + 
                    "<br>Error Id:" + num.ToString()+ 
                    "<br>" + log + 
                    "</div>";
            }
        }
    }
}