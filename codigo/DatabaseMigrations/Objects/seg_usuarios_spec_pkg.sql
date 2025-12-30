create or replace package inv_db.seg_usuarios_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros de usuarios
  */
  
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Agregar un registro de la tabla seg_usuarios_v.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_usuario: ID del usuario en directa relación con la tabla de colaboradores de recursos humanos
    * @p_administrador: S/N que indica si es administrador (tiene todos los permisos y roles) o no, 
    * @p_roles: Id de los roles del usuario, separados por comma, si p_administrador es igual a S entonces p_roles debe ser nulo y viceversa
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure agregar(
    p_id_usuario_procesa             in  varchar2,
    p_id_usuario                     in  seg_usuarios_v.id_usuario%type,
    p_administrador                  in  varchar2,
    p_roles                          in  varchar2,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar un registro de la tabla seg_usuarios_v.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_usuario: ID del usuario en directa relación con la tabla de usuarios del SUIR
    * @p_administrador: S/N que indica si es administrador (tiene todos los permisos y roles) o no, 
    * @p_roles: Id de los roles del usuario, separados por comma, si p_administrador es igual a S entonces p_roles debe ser nulo y viceversa
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_usuario                     in  seg_usuarios_v.id_usuario%type,
    p_administrador                  in  varchar2,
    p_roles                          in  varchar2,
    p_resultado                      out varchar2
  );

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Revoca (elimina) todos los permisos de un usuario
    * @p_id_usuario: ID del usuario en directa relación con la tabla de usuarios del SUIR
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure revocar_acceso(
    p_id_usuario                     in  seg_usuarios_v.id_usuario%type,
    p_resultado                      out varchar2
  );
    
end seg_usuarios_pkg;
