create or replace package inv_db.seg_det_permisos_roles_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros de detalle de permisos de un rol
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Insertar uno o mas registros en la tabla seg_det_permisos_roles_t (permisos de un rol)
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_rol: Id del rol
    * @p_permisos: id de los permisos de página (ej: Permisos: Agregar, Permisos: Modificar, etc) que se agregarán al rol, separados por comma
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure agregar(
    p_id_usuario_procesa             in  varchar2,
    p_id_rol                         in  seg_det_permisos_roles_v.id_rol%type,
    p_permisos                       in  varchar2,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar uno o mas registros de la tabla seg_det_permisos_roles_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_registro: id del registro a modificar (representa el grupo de permisos de una página, ej: Permisos: Agregar, Permisos: Modificar, etc)
    * @p_id_rol: Id del rol id del registro a modificar
    * @p_puede_consultar: S/N que indica si tendrá o no el permiso "consultar" de este grupo de permisos
    * @p_puede_agregar: S/N que indica si tendrá o no el permiso "agregar" de este grupo de permisos
    * @p_puede_modificar: S/N que indica si tendrá o no el permiso "modificar" de este grupo de permisos
    * @p_puede_borrar: S/N que indica si tendrá o no el permiso "borrar" de este grupo de permisos
    * @p_puede_ejecutar: S/N que indica si tendrá o no el permiso "ejecutar" la acción especificada
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_registro                    in  seg_det_permisos_roles_v.id_registro%type,
    p_id_rol                         in  seg_det_permisos_roles_v.id_rol%type,
    p_puede_consultar                in  varchar2,
    p_puede_agregar                  in  varchar2,
    p_puede_modificar                in  varchar2,
    p_puede_borrar                   in  varchar2,
    p_puede_ejecutar                 in  varchar2,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Eliminar uno o mas registros de la tabla seg_det_permisos_roles_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_registro: id del registro (representa el grupo de permisos de una página, ej: Permisos: Agregar, Permisos: Modificar, etc) a eliminar
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure borrar(
    p_id_usuario_procesa             in  varchar2,
    p_id_registro                    in  seg_det_permisos_roles_v.id_registro%type,
    p_resultado                      out varchar2
  );

end seg_det_permisos_roles_pkg;

