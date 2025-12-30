create or replace package inv_db.man_mantenimientos_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para la generacion dinamica de paginas
  */

  subtype t_pagina     is man_paginas_t%ROWTYPE;
  type    t_columnas   is varray(100) of man_det_columnas_paginas_t%ROWTYPE;
  type    t_reportes   is varray(100) of man_reportes_t%ROWTYPE;
  type    t_filtros    is varray(100) of man_det_filtros_paginas_t%ROWTYPE;
  type    t_acciones   is varray(100) of man_det_acciones_paginas_t%ROWTYPE;
  type    t_tabs       is varray(100) of man_det_tabs_paginas_v%ROWTYPE;
  type    t_formulario is table of clob index by varchar2(100);
  subtype a_reporte    is  man_reportes_t%ROWTYPE;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Guardar log de acceso
    * @p_id_usuario: id del usuario que accedió a una opcion del sistema
    * @p_accion: accion que realizó el usuario
  */
  procedure log_acceso(
    p_id_usuario inv_db.man_log_accesos_t.id_usuario%type,
    p_accion     inv_db.man_log_accesos_t.accion%type
  );

  procedure preparar(
    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : analizar el input del usuario logueado y preparar la renderización de una página, en cualquiera de sus posibles estados
      *            consultando en un grid, viendo los detalles de la pagina actual, viendo la documentacion de ayuda de la pagina actual,
      *            sorteando, filtrando, imprimiendo o exportando los datos en pantalla,
      *            viendo, agregando, modificando, borrando o realizando otras acciones sobre los registros
      *            graficando o imprimiendo reportes personalizados , etc.
      *            por ejemplo:
      *            entras a la página de parametros   -> man_preparar_p llama a man_consultar_p y ves un grid de parámetros
      *            haces click en un parametro        -> man_preparar_p si tienes permiso de modificar llama a man_modificar_p y ves la página de editar
      *                                               -> man_preparar_p si no tienes permiso de modificar llama a man_ver_p y ves la página de mirar
      *            haces click en el boton de back    -> man_preparar_p llama a man_consultar_p y ves un grid de parametros
      * @p_id_pagina: Id de la pagina actual
      * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
      * @p_id_usuario_procesa: Id del usuario logueado
      * @p_formulario: Colección de los valores de todos los input-controls en el último post-back
      * @p_resultado: un clob que contiene la renderizacion html de la pagina en el estado que se desea
    */
    p_id_pagina          in out varchar2,
    p_id_sesion          in man_sesiones_t.id_sesion%type,
    p_id_usuario_procesa in varchar2,
    p_formulario         in clob,
    p_resultado          OUT CLOB
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : reinicia (elimina los valores anteriores) de una sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
  */
  procedure sesion_iniciar(
    p_id_sesion      in man_sesiones_t.id_sesion%type
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : lee el valor de una variable almacenada en una sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable cuyo valor se desea consultar
    * @returns valor de la variable de sesion del usuario logueado en la página actual
  */
  function sesion_leer(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : lee el archivo cargado en una variable de sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable cuyo valor se desea consultar
    * @returns devuelve un blob con el contenido de un archivo cargado en una variable de sesion del usuario logueado en la página actual
  */
  function sesion_leer_documento(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  ) return blob;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Guardar un valor en una variable de sesion del usuario logueado en la página actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_usuario: id del usuario logueado
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
    * @p_valor: valor a guardar en dicha variable
  */
  procedure sesion_guardar(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_usuario     in man_sesiones_t.id_usuario%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type,
    p_valor          in man_sesiones_t.valor%type
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : guardar un archivo cargado en una variable de sesion del usuario logueado en la pagina actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_usuario: id del usuario logueado
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
    * @p_documento: contenido del archivo cargado
  */
  procedure sesion_guardar_documento(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_usuario     in man_sesiones_t.id_usuario%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type,
    p_filename       in man_sesiones_t.valor%type,
    p_documento      in blob
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : borrar las variables de OTP de la sesión del usuario logueado
    * @p_id_usuario: id_del usuario logueado
  */
  procedure sesion_borrar(
    p_id_usuario      in man_sesiones_t.id_usuario%type
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : elimina el valor de una llave en una sesion del usuario logueado en la pagina actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
  */
  procedure sesion_borrar(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : encriptar un string mediante el algoritmo text_encode
    * p_texto: texto a desencriptar
    * @returns :texto encriptado
  */
  function encrypt(
    p_texto in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : desencriptar un string encriptado con el algoritmo text_encode
    * p_texto: texto a desencriptar
    * @returns :texto encriptado
  */
  function decrypt(
    p_texto in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : agrega al html una alerta modal que no permite usal la pagina hasta que se presione un botón
    * @p_texto: texto de la alerta
    * @p_icon: icono/tipo de alerta: puede ser success,error,warning,question, entre otros
  */
  function alert(
    p_texto in varchar2,
    p_icon in varchar2
  ) return varchar2;

end man_mantenimientos_pkg;
