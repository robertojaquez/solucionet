create or replace package inv_db.seg_roles_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros de roles (seg_roles_t)
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Insertar un registro en la tabla seg_roles_t y sus permisos en seg_det_permisos_roles_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_rol: Nombre del rol
    * @p_permisos: id de los permisos del rol, separados por comma
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure agregar(
    p_id_usuario_procesa             in  varchar2,
    p_rol                            in  seg_roles_v.rol%type,
    p_permisos             in  varchar2,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar un registro de la tabla seg_roles_t y sus permisos en seg_det_permisos_roles_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol: Id del registro
    * @p_rol: Nombre del rol
    * @p_permisos: id de los permisos del rol, separados por comma
    * @p_estado_registro: Estado actual del registro
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_rol                         in  seg_roles_v.id_rol%type,
    p_rol                            in  seg_roles_v.rol%type,
    p_permisos                     in  varchar2,
    p_estado_registro                        in  seg_roles_v.estado_registro%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Eliminar un registro de la tabla seg_roles_t y sus permisos en seg_det_permisos_roles_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol: Id del registro a eliminar
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure borrar(
    p_id_rol                         in  seg_roles_v.id_rol%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Revocar (eliminar) los permisos de un rol
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol: Id del rol al que serán revocados los permisos
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure revocar_permisos(
    p_id_rol                         in  seg_roles_v.id_rol%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo :Remover un rol a todos los usuarios que lo tienen
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol: Id del rol que será removido
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure remover_usuarios(
    p_id_rol                         in  seg_roles_v.id_rol%type,
    p_resultado                      out varchar2
  );

end seg_roles_pkg;

