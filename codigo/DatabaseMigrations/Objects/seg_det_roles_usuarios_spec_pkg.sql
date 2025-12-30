create or replace package inv_db.seg_det_roles_usuarios_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros del detalle de roles de un usuario
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Insertar un registro en la tabla seg_det_roles_usuarios_t (roles de un usuario).
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_usuario: Id del usuario registrado para usar este módulo
    * @p_id_rol: Id de uno de los roles de este módulo que se desea asignar a al usuario
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure agregar(
    p_id_usuario_procesa             in  varchar2,
    p_id_usuario                     in  seg_det_roles_usuarios_v.id_usuario%type,
    p_id_rol                         in  seg_det_roles_usuarios_v.id_rol%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar un registro de la tabla seg_det_roles_usuarios_t (roles de un usuario).
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol_usuario: Id del registro
    * @p_id_usuario: Id del usuario registrado para usar este módulo
    * @p_id_rol: Id de uno de los roles de este módulo asignado a este usuario
    * @p_estado_registro: Estado actual del registro, A=Activo,I=Inactivo
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_rol_usuario                 in  seg_det_roles_usuarios_v.id_rol_usuario%type,
    p_id_usuario                     in  seg_det_roles_usuarios_v.id_usuario%type,
    p_id_rol                         in  seg_det_roles_usuarios_v.id_rol%type,
    p_estado_registro                in  seg_det_roles_usuarios_v.estado_registro%type,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Eliminar un registro de la tabla seg_det_roles_usuarios_t (roles de un usuario).
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol_usuario: Id del registro de usuario/rol que se desea eliminar
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure borrar(
    p_id_usuario_procesa             in  varchar2,
    p_id_rol_usuario                 in  seg_det_roles_usuarios_v.id_rol_usuario%type,
    p_resultado                      out varchar2
  );

end seg_det_roles_usuarios_pkg;
