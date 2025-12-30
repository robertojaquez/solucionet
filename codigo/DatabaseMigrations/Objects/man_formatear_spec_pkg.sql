create or replace package inv_db.man_formatear_pkg is
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el formatear alginos valores de cara al usuario
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : formatea una fecha en formato dd/mm/yyyy
    * @p_fecha fecha que se desea formatear
    * returns string que representa la fecha en formato dd/mm/yyyy
  */
  function y_m_d(
    p_fecha in date
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : formatea un string que puede ser una fecha, en diferentes formatos, a fecha en formato dd/mm/yyyy
    * @p_fecha texto que parece una fecha y que se desea llevar a dd/mm/yyyy
    * returns string que representa la fecha en formato dd/mm/yyyy
  */
  function y_m_d(
    p_fecha in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : retorna las descripciones de varios mensaje de error específicoe para un método
    * @p_mensajes codigos de mensajes a devolver, separados por pipes
    * @returns mensajes de error al usuario, separados por <br>
  */
  function mensaje_de_error(
    p_mensajes in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : retorna la descripcion de un mensaje de error específico para un método
    *            si no existe, lo crea con el texto error desconocido, para que pueda se modificado en el sistema sin tener que
    *            hacer un pase a producción
    * @p_codigo codigo del mensaje a devolver
    * @returns mensaje de error al usuario
  */
  function mensaje(
    p_codigo man_mensajes_t.codigo%type
  )
  return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : enmascarar el numero de movil de un usuario para no mostrarlo completo al autenticarse por otp
    * @p_movil número de movil a enmascarar
    * @returns número de movil enmascarado
  */
  function enmascarar_movil(
    p_movil in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : enmascarar la direccion de correo de un usuario para no mostrarla completa al autenticarse por otp
    * @p_email direccion de correo a enmascarar
    * @returns direccion de correo enmascarada
  */
  function enmascarar_email(
    p_email in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : devolver un registro de trazabilidad (cambios a un registro, antes y despues) formateado en html para su visualización
    * @p_accion titulo de la acción que se realizó (agregar, modificar,borrar, etc.)
    * @p_id_trazabilidad id del registro de trazabilidad que se desea renderizar
    * @returns un clob con la renderización html de la trazabilidad de un registro
  */
  function detalle_trazabilidad (
    p_accion in varchar2,
    p_id_trazabilidad in inv_db.man_trazabilidad_t.id_trazabilidad%type
  )
  return clob;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir un número en su representación verbal
    * @P_NUMEROENTERO numero que se desea convertir, solo la parte entera porque se implementó así para imprimir cheques y los decimales se ponen numéricamente
    * @returns la representación verbal del numero, ejemplo: 12345 -> Doce Mil Trescientos Cuarente y Cinco
  */
  FUNCTION numero_a_letras(
    P_NUMEROENTERO IN NUMBER
  ) RETURN VARCHAR2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir a CLOB el blob resultante de la carga de un archivo
    * @p_blob blob que se desea convertir
    * @returns data del blob en formato clob
  */
  function clobfromblob(
    p_blob blob
  ) return clob;
  
   /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir un CLOB a blob
    * @p_clob clob que se desea convertir
    * @returns data del clob en formato blob
   */
   function clobtoblob(p_clob CLOB) return BLOB;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : hace decode de las etiquetas HTML a su representacion ASCII
    * p_texto  : texto que se desea decodificar de html a ascii
    * @returns : texto ascii decodificado
  */
  function htmlDecode(
    p_texto in varchar2
  )
  return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : codifica la comilla simple en dos comillas simples para que la construccion de queries dinamicos no se rompa cuando el usuario envie
    *            filtros con comillas en la data
    * p_texto  : texto que se desea codificar
    * @returns : texto codificado
  */
  function sqlEncode(
    p_texto in varchar2
  )
  return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Convierte un blob en su representacion textual en formato base64
    * @p_blob  : blob que se desea codificar
    * @returns : un clob conteniendo la representacion base64 del blob
  */
  FUNCTION base64encode(p_blob IN BLOB)
    RETURN CLOB;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/04/2025
    * Objetivo : Dada una plantilla HTML, un SQL y un unico valor, devuelve un mensaje a enviar
    * p_html      plantilla html del mensaje
    * p_sql       sentencia sql que obtiene todos los [campos] que se mensionan en la plantilla
    * p_id_registro id del registro individual a devolver, cada SQL lo pide como parametro :id_registro
    * @returns : la plantilla ya parseada con los valores que devuelve el SQL
  */
  function mail_merge(
    p_html     in clob, 
    p_sql      in clob, 
    p_id_registro in varchar2
  ) return clob;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 09/06/2025
    * Objetivo : Dada una plantilla HTML, un SQL y un unico valor, devuelve un mensaje a enviar
      p_modo: modo que construira el objeto tabla o divs
    * p_aligments alineación de las columnas, si hay tres columnas (ej: codigo,fecha y monto), mandar 3 letras: 'LCR'
    * p_sql sentencia sql que obtiene todos los [campos] que se mensionan en la plantilla
    * p_id_registro id del registro individual a devolver, cada SQL lo pide como parametro :id_registro
    * @returns : la plantilla ya parseada con los valores que devuelve el SQL
  */
  
  function sql_to_html(
    p_modo      in varchar2,  -- tabla o divs
    p_sql       in varchar2, 
    p_aligments in varchar2,  --alineación de las columnas, si hay tres columnas (ej: codigo,fecha y monto), mandar 3 letras: 'LCR'
    p_id_registro in varchar2
  ) return clob;

  procedure enviar_email(
    p_asunto in varchar2, 
    p_mensaje in varchar2, 
    p_destinatario in varchar2
  );

end man_formatear_pkg;
