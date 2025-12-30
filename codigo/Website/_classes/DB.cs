using System;
using System.Data;
using Oracle.DataAccess.Types;
using Oracle.DataAccess.Client;
using System.Collections.Generic;
using System.Configuration;

namespace Website
{
    public static class DB
    {
        // string de coneccion a la base de datos, esto debe ponerse encriptado en un archivo de configuracion
        private static String connectionString = ConfigurationManager.ConnectionStrings["desarrollo"].ConnectionString;

        /// <summary>Ejecuta un query y retornar un dataset</summary>
        /// <param name="sentencia">Sentencia select a ejecutar, debe devolver un dataset</param>
        /// <param name="parametros">Array de parametros requeridos por la sentencia</param>
        /// <returns>El primer datatable del dataset que retorne la sentencia al ser ejecutada</returns>
        public static DataTable EjecutarSentencia(string sentencia, params Object[][] parametros)
        {
            OracleConnection oraConn = new OracleConnection(connectionString);
            oraConn.Open();
            OracleCommand nls_date_format = new OracleCommand("alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy'", oraConn);
            nls_date_format.ExecuteNonQuery();

            OracleCommand oracleCommand = new OracleCommand(sentencia, oraConn);
            oracleCommand.CommandType = CommandType.Text;
            foreach(Object[] param in parametros) {
                if (param.Length == 5)
                {
                    //5 parametros es la llamada que incluye el tipo de dato más la longitud de cada parametro
                    oracleCommand.Parameters.Add(new OracleParameter()
                    {
                        ParameterName = (String)param[0],
                        OracleDbType = (OracleDbType)param[1],
                        Size = (int)param[2],
                        Direction = (ParameterDirection)param[3],
                        Value = param[4]
                    });
                } else
                {
                    //4 parametros es la llamada que solo indica el tipo de dato de cada parámetro
                    oracleCommand.Parameters.Add(new OracleParameter()
                    {
                        ParameterName = (String)param[0],
                        OracleDbType = (OracleDbType)param[1],
                        Direction = (ParameterDirection)param[2],
                        Value = param[3]
                    });
                }
            }
            DataSet dataset = new DataSet();
            OracleDataAdapter dataAdapter = new OracleDataAdapter(oracleCommand);
            dataAdapter.Fill(dataset);
            oraConn.Close();

            return dataset.Tables[0];
        }

        /// <summary>Método interno, define un objeto de tipo stored procedure y lo llena con los parámetros especificados</summary>
        /// <param name="procedimiento">Nombre del stored procedure a ejecutar</param>
        /// <param name="parametros">Array de parámetros requeridos por el stored procedure</param>
        /// <returns>Un objeto de tipo OracleCommand, ya conectado, definido y parametizado, para más fácil uso</returns>
        private static OracleCommand DefinirProcedimiento(String procedimiento, Object[][] parametros)
        {
            OracleConnection oraConn = new OracleConnection(connectionString);
            oraConn.Open();
            OracleCommand nls_date_format = new OracleCommand("alter session set NLS_DATE_FORMAT = 'dd/mm/yyyy'", oraConn);
            nls_date_format.ExecuteNonQuery();

            OracleCommand oracleCommand = new OracleCommand(procedimiento, oraConn);
            oracleCommand.CommandType = CommandType.StoredProcedure;
            foreach(Object[] param in parametros) {
                if (param.Length == 5)
                {
                    //5 parametros es la llamada que incluye el tipo de dato más la longitud de cada parametro
                    oracleCommand.Parameters.Add(new OracleParameter()
                    {
                        ParameterName = (String)param[0],
                        OracleDbType = (OracleDbType)param[1],
                        Size = (int)param[2],
                        Direction = (ParameterDirection)param[3],
                        Value = param[4]
                    });
                } else
                {
                    //4 parametros es la llamada que solo indica el tipo de dato de cada parámetro
                    oracleCommand.Parameters.Add(new OracleParameter()
                    {
                        ParameterName = (String)param[0],
                        OracleDbType = (OracleDbType)param[1],
                        Direction = (ParameterDirection)param[2],
                        Value = param[3]
                    });
                }
            }
            return oracleCommand;
        }

        /// <summary>Ejecuta un stored procedure que no devuelve ningun parametro (en teoría no debe usarse pues no debería haber ninguno)</summary>
        /// <param name="procedimiento">Nombre del Stored procedure a ejecutar</param>
        /// <param name="parametros">Array de parametros requeridos por el stored procedure</param>
        /// <returns></returns>
        public static void EjecutarProcedimiento(String procedimiento, Object[][] parametros)
        {
            OracleCommand oracleCommand = DB.DefinirProcedimiento(procedimiento, parametros);
            oracleCommand.ExecuteNonQuery();
            oracleCommand.Connection.Close();
        }

        /// <summary>Ejecuta un stored procedure que devuelve un parametro de salida de tipo String</summary>
        /// <param name="procedimiento">Nombre del Stored procedure a ejecutar</param>
        /// <param name="parametros">Array de parametros requeridos por el stored procedure</param>
        /// <returns>El string contenido en el parametro de salida que indique parametroDeSalida</returns>
        public static String EjecutarProcedimientoDevuelveString(String procedimiento, String parametroDeSalida, Object[][] parametros)
        {
            OracleCommand oracleCommand = DB.DefinirProcedimiento(procedimiento, parametros);
            oracleCommand.ExecuteNonQuery();
            String result = oracleCommand.Parameters[parametroDeSalida].Value.ToString();
            oracleCommand.Connection.Close();
            return result;
        }

        /// <summary>Ejecuta un stored_procedure que devuelve un parametro de salida de tipo Clob</summary>
        /// <param name="procedimiento">Nombre del Stored procedure a ejecutar</param>
        /// <param name="parametros">Array de parametros requeridos por el stored procedure</param>
        /// <returns>El string contenido en el parametro de salida que indique parametroDeSalida</returns>
        public static String EjecutarProcedimientoDevuelveClob(String procedimiento, String parametroDeSalida, Object[][] parametros)
        {
            OracleCommand oracleCommand = DB.DefinirProcedimiento(procedimiento, parametros);
            oracleCommand.ExecuteNonQuery();
            OracleClob valor = (OracleClob)oracleCommand.Parameters[parametroDeSalida].Value;
            String result = "";
            if (!valor.IsNull)
            {
                result = Convert.ToString(valor.Value);
            }
            oracleCommand.Connection.Close();
            return result;
        }

        /// <summary>Ejecuta un stored_procedure que devuelve un array de parametros de salida</summary>
        /// <param name="procedimiento">Nombre del Stored procedure a ejecutar</param>
        /// <param name="parametros">Array de parametros requeridos por el stored procedure</param>
        /// <returns>Una coleccion tipo Dictionary con todos los parametro y sus respectivos valroes</returns>
        public static Dictionary<String, String> EjecutarProcedimientoDevuelveParametros(String procedimiento, Object[][] parametros)
        {
            OracleCommand oracleCommand = DB.DefinirProcedimiento(procedimiento, parametros);
            oracleCommand.ExecuteNonQuery();

            Dictionary<string, String> result = new Dictionary<String, String>();

            foreach (OracleParameter parameter in oracleCommand.Parameters)
            {
                Object tempObject = parameter.Value;
                if (tempObject is OracleClob) {
                    OracleClob oracleClob = (OracleClob)tempObject;
                    result.Add(parameter.ParameterName, oracleClob.Value);
                } else {
                    result.Add(parameter.ParameterName, System.Convert.ToString(parameter.Value));
                }
            }
            oracleCommand.Connection.Close();
            return result;
        }

    }
}