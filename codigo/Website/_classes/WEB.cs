using System;
using System.Configuration;
using System.Data;
using System.Text;
using Oracle.DataAccess.Client;
using System.Security.Cryptography;
using System.Collections.Specialized;
using static System.Collections.Specialized.BitVector32;
using System.Web;
using System.Drawing.Imaging;
using System.IO;
using System.Drawing;

namespace Website
{
    public class Web
    {

        /// <summary>Ejecuta las acciones necesarias cuando un usuario acaba de autenticarse satisfactoriamente</summary>
        /// <param name="idUsuario">Id del usuario que acaba de autenticarse</param>
        public static void Entrar()
        {
            // recojer el usuario autenticado
            if (System.Web.HttpContext.Current.Session["id_usuario"] is null)
            {
                String idUsuario = HttpContext.Current.User.Identity.Name.ToString().ToUpper().Trim();
                if (idUsuario.StartsWith("TSS2\\")) { idUsuario = idUsuario.Substring(5);}

                // llenar las variables de entorno
                System.Web.HttpContext.Current.Session["id_usuario"] = idUsuario;

                String inv = DB.EjecutarProcedimientoDevuelveClob("inv_db.seg_autenticacion_pkg.obtener_inventario_predeterminado", "p_resultado", new Object[][] {
                    new Object[] {"p_id_usuario", OracleDbType.Varchar2, ParameterDirection.Input,       idUsuario},
                    new Object[] {"p_resultado",  OracleDbType.Clob,     ParameterDirection.InputOutput, null }
                });

                System.Web.HttpContext.Current.Session["id_inventario"] = "";
                System.Web.HttpContext.Current.Session["inventario"] = "";
                if (inv.StartsWith("OK:"))
                {
                    System.Web.HttpContext.Current.Session["id_inventario"] = inv.Substring(3,3);
                    System.Web.HttpContext.Current.Session["inventario"] = inv.Substring(7);
                }

                System.Web.HttpContext.Current.Session["inbox_conteo_pendientes"] = "~"; //siempre que sea diferente al minuto, lo refrescará
                System.Web.HttpContext.Current.Session["logfile"] = ConfigurationManager.AppSettings["logfile"];
                System.Web.HttpContext.Current.Session["iniciales"] = idUsuario.Substring(0,1);
                if (idUsuario.Contains("_"))
                {
                    System.Web.HttpContext.Current.Session["iniciales"] = System.Web.HttpContext.Current.Session["iniciales"] + idUsuario.Substring(idUsuario.IndexOf("_")+1, 1);
                }

                // generar el menu de opciones (para no tener que generarlo en cada post-back como el SUIR
                String menu = DB.EjecutarProcedimientoDevuelveClob("inv_db.seg_autenticacion_pkg.generar_menu", "p_resultado", new Object[][] {
                    new Object[] {"p_id_usuario", OracleDbType.Varchar2, ParameterDirection.Input,       idUsuario},
                    new Object[] {"p_id_inventario", OracleDbType.Int32, ParameterDirection.Input, (string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_inventario"] as string))? null : System.Web.HttpContext.Current.Session["id_inventario"] },
                    new Object[] {"p_resultado",  OracleDbType.Clob,     ParameterDirection.InputOutput, null }
                });
                System.Web.HttpContext.Current.Session["menu"] = menu;


            }
        }

        /// <summary>Destruye la sesión actual</summary>
        public static void DestruirSesion()
        {
            System.Web.HttpContext.Current.Session.Clear();
            System.Web.HttpContext.Current.Session.Abandon();
        }

        /// <summary>Desabilita el caché, esto es necesario porque las páginas se generan dinámicamente utilizando el mismo URL</summary>
        public static void DeshabilitarCache()
        {
            System.Web.HttpContext.Current.Response.Cache.SetCacheability(HttpCacheability.NoCache); //Cache-Control : no-cache, Pragma : no-cache
            System.Web.HttpContext.Current.Response.Cache.SetExpires(DateTime.Now.AddDays(-1)); //Expires : date time
            System.Web.HttpContext.Current.Response.Cache.SetNoStore(); //Cache-Control :  no-store
            System.Web.HttpContext.Current.Response.Cache.SetProxyMaxAge(new TimeSpan(0, 0, 0)); //Cache-Control: s-maxage=0
            System.Web.HttpContext.Current.Response.Cache.SetValidUntilExpires(false);
            System.Web.HttpContext.Current.Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches);//Cache-Control:  must-revalidate
        }

        /// <summary>Genera un string random en la longitud deseada</summary>
        /// <param name="longitudDeseada">Número entero que indica la longitud del string random deseado</param>
        /// <returns>Un string random en la longitud deseada</returns>
        public static String RandomString(int longitudDeseada)
        {
            Random random = new Random();
            string characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
            char[] randomString = new char[longitudDeseada];
            for (int i = 0; i < longitudDeseada; i++) { randomString[i] = characters[random.Next(characters.Length)]; }
            return new string(randomString);
        }

        /// <summary>Codifica a HTML algunos caracteres internacionales comunes en el español de Republica Dominicana</summary>
        /// <param name="texto">Texto al que se desea codificar los caracteres internacionales más comunes.</param>
        /// <returns>Un string con los caracteres internacionales comunas ya codificados en HTML.</returns>
        public static String HtmlEncode(String texto)
        {
            String resultado = texto;
            // minusculas
            resultado = resultado.Replace("á", "&aacute;");
            resultado = resultado.Replace("é", "&eacute;");
            resultado = resultado.Replace("í", "&iacute;");
            resultado = resultado.Replace("ó", "&oacute;");
            resultado = resultado.Replace("ú", "&uacute;");
            resultado = resultado.Replace("ü", "&uuml;");
            resultado = resultado.Replace("ñ", "&ntilde;");
            // mayusculas
            resultado = resultado.Replace("Á", "&Aacute;");
            resultado = resultado.Replace("É", "&Eacute;");
            resultado = resultado.Replace("Í", "&Iacute;");
            resultado = resultado.Replace("Ó", "&Oacute;");
            resultado = resultado.Replace("Ú", "&Uacute;");
            resultado = resultado.Replace("Ü", "&Uuml;");
            resultado = resultado.Replace("Ñ", "&Ntilde;");
            return resultado;
        }

        /// <summary>Codifica a HTML algunos caracteres especiales que interfieren con los javascript de alertas</summary>
        /// <param name="texto">Texto al que se desea codificar los caracteres especiales que interfieren con javascript.</param>
        /// <returns>Un string con los caracteres especiales ya codificados en HTML.</returns>
        public static String HtmlEscape(String texto)
        {
            String resultado = texto;
            resultado = resultado.Replace("\"", "&quot;");
            resultado = resultado.Replace("'", "&apos;");
            resultado = resultado.Replace("<", "&lt;");
            resultado = resultado.Replace(">", "&gt;");
            resultado = resultado.Replace("&", "&amp;");
            return resultado;
        }

        private static ImageCodecInfo GetEncoder(ImageFormat format)
        {
            ImageCodecInfo[] codecs = ImageCodecInfo.GetImageDecoders();
            foreach (ImageCodecInfo codec in codecs)
            {
                if (codec.FormatID == format.Guid)
                {
                    return codec;
                }
            }
            return null;
        }

        public static byte[] ReduceImageSize(byte[] imageBytes, int quality)
        {
            using (MemoryStream memoryStream = new MemoryStream(imageBytes))
            {
                using (Image image = Image.FromStream(memoryStream))
                {
                    ImageCodecInfo jgpEncoder = GetEncoder(ImageFormat.Jpeg);
                    EncoderParameters myEncoderParameters = new EncoderParameters(1);
                    EncoderParameter myEncoderParameter = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
                    myEncoderParameters.Param[0] = myEncoderParameter;

                    using (MemoryStream outputStream = new MemoryStream())
                    {
                        image.Save(outputStream, jgpEncoder, myEncoderParameters);
                        return outputStream.ToArray();
                    }
                }
            }
        }

    }
}