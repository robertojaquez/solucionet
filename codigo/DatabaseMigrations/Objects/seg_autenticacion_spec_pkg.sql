create or replace package inv_db.seg_autenticacion_pkg is
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de la autenticación de usuarios y la entrada al sistema
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Hashear un texto mediante el algoritmo MD5, compatible con el algoritmo utilizado por el SUIRPLUS
    * @p_password texto a hashear
    * @returns el texto provisto, hasheado mediante el algoritmo MD5
  */
  function md5(
    p_password in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Hashear un texto mediante el algoritmo HMAC_SH512, compatible con el algoritmo utilizado por el SUIRPLUS
    * @p_id_usuario id del usuario cuyo password se desea hashear
    * @p_password texto a hashear
    * @returns el texto provisto, hasheado mediante el algoritmo HMAC_SH512
  */
  function hmac(
    p_id_usuario in varchar2, p_password in varchar2
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Generar el menú de opciones disponibles para un usuario basándonos en sus permisos
    *            Nota: el menú se genera solo una vez al loguearse el usuario para evitar regenerarlo en cada post-back como hace el SUIR
    *            De todas formas la seguridad del sistema responde a los permisos, no a las opciones visibles en el menu
    * @p_id_usuario: id del usuario que acaba de loguarse
    * @p_inventario: Id del inventario a que tiene acceso el usuario
    * @p_resultado: un clob con la renderizacíon html del menú que se quedará en una variable de sesión de .net para no volver a ejecutarlo
  */
  procedure generar_menu(
    p_id_usuario in varchar2,
    p_id_inventario int,
    p_resultado out clob
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Encontrar uno de los inventarios a que tiene permiso el usuario para usarlo como predeterminado al loguearse
    * @p_id_usuario: id del usuario que acaba de loguarse
    * @p_resultado: un string con el id del inventario predeterminado
  */
  procedure obtener_inventario_predeterminado(
    p_id_usuario in varchar2,
    p_resultado out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : generar tarjetas de vienbenida para el usuario logueado en base a las paginas publicas
    *            estas páginas podrían incluir cada una un SQL que determina si un registro está pendiente
    *            si dicho SQL es ejecutado y trae registros, lo renderizamos en la pantalla de bienvenida
    *            algunas de estas consultas pueden ser costosas, esto no se ejecuta mas de una vez por minuto
    * @p_id_usuario: id del usuario logueado
    * @p_id_inventario: id del inventario que tiene seleccionado
    * @p_resultado: un clob con la renderización HTML de la lista de pendientes de la pagina de bienvenida
  */
  procedure generar_bienvenida(
    p_id_usuario in varchar2,
    p_id_inventario int,
    p_resultado out clob
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Contar la cantidad de mensajes sin leer en el buzon de mensajes del usuario logueado
    * @p_id_usuario: id del usuario logueado
    * @p_resultado: Cantidad de mensajes sin leer
  */
  procedure contar_mensajes_pendientes(
    p_id_usuario                     in  varchar2,
    p_resultado                      out number
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : determina si un usuario tiene un permiso
    * @p_id_usuario: id del usuario logueado
    * @p_id_permiso: id del permiso que se desea verificar si el usuario lo tiene asignado en cualesquiera de sus roles
    *                nota: no se asignan permisos directos, solo a travez de roles
    *                para el rol administrador todos los permisos, actuales y futuros, devuelven S, sin necesidad de asignarlos
    * @returns S/N indicando si el usuario especificado tiene el permiso especificado
  */
  function tiene_permiso(
    p_id_usuario in inv_db.seg_usuarios_v.id_usuario%type,
    p_id_permiso in inv_db.seg_permisos_t.id_permiso%type
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Inserta un registro en la tabla html_mail_t del SUIR para que sea enviado por correo
    * @p_sender: Dirección de correo de quien envía el mensaje, se sobre-escribe automáticamente a noreply@... en producción
    * @p_recipient: Dirección de correo de quien recibirá en mensaje
    * @p_subject: Asunto correspondiente al email que se enviará
    * @p_message: Texto del mensaje a enviar
  */
  procedure enviar_email (
    p_sender      IN VARCHAR2,
    p_recipient   IN LONG,
    p_subject     IN VARCHAR2,
    p_message     varchar2
  );


end seg_autenticacion_pkg;
