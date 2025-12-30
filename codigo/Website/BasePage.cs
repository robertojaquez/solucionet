using System;
using System.Data;
using System.Web;
using System.Web.UI;
using Oracle.DataAccess.Client;

namespace Website._sys
{
    public class BasePage: Page
    {
        /// <summary>Al cargarse una página, si no está relacionada a una sesion activa redirije el usuario a la página de Login</summary>
        protected override void OnLoad(EventArgs e)
        {
            // si la session murió, intentar entrar
            if (string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_usuario"] as string)) {
                Web.Entrar();
            }

            // si no tiene permiso a ningun inventario ni a ninguna opcion, sacarlo
            if (
             string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["id_inventario"] as string)
             &&
             string.IsNullOrEmpty(System.Web.HttpContext.Current.Session["menu"] as string)
             &&
             HttpContext.Current.Request.Url.AbsolutePath.ToLower().Contains("/paginas.aspx")
            )
            {
                Response.Redirect("/NoBienvenido.aspx");
            } else
            {
                Web.Entrar();
            }

            String pendientes = DB.EjecutarProcedimientoDevuelveString("inv_db.seg_autenticacion_pkg.contar_mensajes_pendientes", "p_resultado", new Object[][] {
                new Object[] {"p_id_usuario", OracleDbType.Varchar2, ParameterDirection.Input, Session["id_usuario"]},
                new Object[] {"p_resultado",  OracleDbType.Int64,   ParameterDirection.Output, null }
            });
            if (pendientes == "0")
            {
                Session["inbox_conteo_pendientes"] = "";
            }
            else
            {
                Session["inbox_conteo_pendientes"] = pendientes;
            }

            base.OnLoad(e);
        }
    }
}