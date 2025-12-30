create or replace package body inv_db.seg_buzon_mensajes_pkg as
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
  ) is
  begin
    delete from inv_db.seg_buzon_mensajes_t
    where id_buzon_mensaje = p_ID_BUZON_MENSAJE;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('borrado');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end borrar;

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
  ) return varchar2 is
   -- este pragma es necesario porque esta función se ejecuta durante el select que trae el registro del buzon a ser leido
   -- y debe marcarlo como leido inmediatamente, esta funcion se utiliza solo al hacer click en un mensaje del buzon
   PRAGMA AUTONOMOUS_TRANSACTION;
   reg_mensaje inv_db.seg_buzon_mensajes_t%rowtype;
  begin
    select *
    into reg_mensaje
    from inv_db.seg_buzon_mensajes_t m
    where m.id_buzon_mensaje = p_id_mensaje;

    if reg_mensaje.leido = 'N' then
      update inv_db.seg_buzon_mensajes_t m
        set  m.leido_en = sysdate,
             m.leido = 'S'
       where m.id_buzon_mensaje = p_id_mensaje;
       commit;
    end if;

    return to_char(reg_mensaje.enviado_en,'dd/mm/yyyy hh:mi:ss AM');
  end marcar_leido;

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
  ) is
  begin
    select count(*)
    into p_resultado
    from inv_db.seg_buzon_mensajes_t m
    where m.id_usuario = p_id_usuario
    and m.leido = 'N';
  exception when others then
    p_resultado := 0;
  end contar_pendientes;

end seg_buzon_mensajes_pkg;

