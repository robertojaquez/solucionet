using System;
using System.Data;
using Website._sys;
using Oracle.DataAccess.Client;
using System.Web;
using System.Globalization;
using System.Drawing;
using System.Web.UI.WebControls;

namespace Website
{
    public partial class Bienvenida : BasePage
    {
        /// <summary>
        /// Al cargarse la página de bienvenida, elimina las variables de sesion del usuario en otras páginas y genera la lista de tareas pendientes
        /// </summary>
        /// <param name="sender">Parámetro standard de .net para estos casos</param>
        /// <param name="e">Parámetro standard de .net para estos casos</param>
        protected void Page_Load(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_usuario"] as string))
            {
                Web.Entrar();
            }


            DB.EjecutarProcedimiento("inv_db.man_mantenimientos_pkg.sesion_borrar", new Object[][] { 
                new object[] { "p_id_usuario", OracleDbType.Varchar2, 100, ParameterDirection.Input, Session["id_usuario"] }
            });

            /* Si elijieron un inventario de la tarjeta de inventarios */
            if (Request.Form["ID_INVENTARIO"] != null)
            {
                System.Web.HttpContext.Current.Session["id_inventario"] = Request.Form["ID_INVENTARIO"].Substring(0, 3);
                System.Web.HttpContext.Current.Session["inventario"] = Request.Form["ID_INVENTARIO"].Substring(4);
            }

            // generar el menu de opciones (para no tener que generarlo en cada post-back como el SUIR
            String menu = DB.EjecutarProcedimientoDevuelveClob("inv_db.seg_autenticacion_pkg.generar_menu", "p_resultado", new Object[][] {
                    new Object[] {"p_id_usuario", OracleDbType.Varchar2, ParameterDirection.Input,       Session["id_usuario"]},
                    new Object[] {"p_id_inventario", OracleDbType.Int32, ParameterDirection.Input, (string.IsNullOrEmpty(Session["id_inventario"] as string))? null : Session["id_inventario"] },
                    new Object[] {"p_resultado",  OracleDbType.Clob,     ParameterDirection.InputOutput, null }
            });

            if (
                 string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_inventario"] as string)
                 &&
                 string.IsNullOrEmpty(menu)
            )
            {
                Response.Redirect("/NoBienvenido.aspx");
            } else {
                System.Web.HttpContext.Current.Session["menu"] = menu;

                // generar el menu de opciones
                String m_bienvenida;
                m_bienvenida = DB.EjecutarProcedimientoDevuelveClob("inv_db.seg_autenticacion_pkg.generar_bienvenida", "p_resultado", new Object[][] {
                    new Object[] {"p_id_usuario", OracleDbType.Varchar2, ParameterDirection.Input, Session["id_usuario"]},
                    new Object[] {"p_id_inventario", OracleDbType.Int32, ParameterDirection.Input, (string.IsNullOrEmpty(Session["id_inventario"] as string))? null : Session["id_inventario"] },
                    new Object[] {"p_resultado",  OracleDbType.Clob,     ParameterDirection.InputOutput, null }
                });
                Tarjetas.InnerHtml = m_bienvenida;
            }
        }
    }
}