create or replace package inv_db.seg_permisos_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros de permisos (seg_permisos_t)
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Activar un registro de la tabla seg_permisos_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_permiso: id del permiso que será activado
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure activar(
    p_id_usuario_procesa             in  varchar2,
    p_id_permiso                     in  seg_permisos_v.id_permiso%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Inactivar un registro de la tabla seg_permisos_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_permiso: id del permiso que será inactivado
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure inactivar(
    p_id_usuario_procesa             in  varchar2,
    p_id_permiso                     in  seg_permisos_v.id_permiso%type,
    p_resultado                      out varchar2
  );

end seg_permisos_pkg;

