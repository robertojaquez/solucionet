create or replace package inv_db.seg_buzon_mensajes_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros del buzon de mensajes
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Eliminar un registro de la tabla seg_buzon_mensajes_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_buzon_mensaje: ID del registro a eliminar
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure borrar(
    p_id_buzon_mensaje               in  seg_buzon_mensajes_v.id_buzon_mensaje%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : esta funcion tiene dos objetivos simultaneos
    *            1) Marcar como Leido un registro de la tabla seg_buzon_mensajes_t
    *            2) Devolver la fecha en que el registro fue enviado
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_buzon_mensaje: ID del registro a obtener y/o marcar como leido
    * @returns: la fecha de envío del mensaje (y ya que lo leyó, lo marca leido)
  */
  function marcar_leido(
    p_id_mensaje                     in number
  ) return varchar2;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Contar los registros sin leeer en el buzon de mensajes del usuario logueado
    * @p_id_usuario: ID del usuario logueado
    * @p_resultado: retorna el numero de mensajes sin leer en el buzon de mensajes del usuario
  */
  procedure contar_pendientes(
    p_id_usuario                     in  varchar2,
    p_resultado                      out number
  );

end seg_buzon_mensajes_pkg;

