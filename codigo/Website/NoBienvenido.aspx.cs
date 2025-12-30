using System;
using System.Data;
using Website._sys;
using Oracle.DataAccess.Client;
using System.Web;
using System.Globalization;
using System.Drawing;

namespace Website
{
    public partial class NoBienvenido : BasePage
    {
        /// <summary>
        /// Muestra un error de usuario no bienvenido
        /// </summary>
        /// <param name="sender">Parámetro standard de .net para estos casos</param>
        /// <param name="e">Parámetro standard de .net para estos casos</param>
        protected void Page_Load(object sender, EventArgs e)
        {
            Web.DestruirSesion();
        }
    }
}