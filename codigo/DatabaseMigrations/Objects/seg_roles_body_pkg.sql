create or replace package body inv_db.seg_roles_pkg as
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
    p_permisos                     in  varchar2,
    p_resultado                      out varchar2
  ) is
    v_id_reg  int;
  begin
    insert into inv_db.seg_roles_t (
      rol,
      agregado_por,
      agregado_en,
      estado_registro
    ) values (
      p_rol,
      p_id_usuario_procesa,
      sysdate,
      'A'
    ) returning id_rol into v_id_reg;

    -- insertar los permisos que estan seleccionados
    insert  into inv_db.seg_det_permisos_roles_t( id_rol,id_permiso,agregado_por,agregado_en,estado_registro)
    select v_id_reg,id_permiso,p_id_usuario_procesa,sysdate,'A'
    from inv_db.seg_permisos_t n
    where n.id_permiso in(SELECT REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)FROM DUAL
                          CONNECT BY REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)IS NOT NULL);

    p_resultado := 'OK|'||man_formatear_pkg.mensaje('agregado');
    commit;

  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end agregar;

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
  ) is
  begin
    update inv_db.seg_roles_t set
      rol                           = p_rol,
      modificado_por                = p_id_usuario_procesa,
      modificado_en                 = sysdate,
      estado_registro                       = p_estado_registro
    where id_rol = p_id_rol;

    -- quitar los permisos pero que ya no estan marcados
    delete from  inv_db.seg_det_permisos_roles_t pr
     where pr.id_rol = p_id_rol
       and (p_permisos is null or pr.id_permiso not in (SELECT REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)FROM DUAL
                                                        CONNECT BY REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)IS NOT NULL));

    -- insertar los permisos que estan seleccionados
    insert into inv_db.seg_det_permisos_roles_t( id_rol,id_permiso,agregado_por,agregado_en,estado_registro)
    select p_id_rol,id_permiso,p_id_usuario_procesa,sysdate,'A'
    from inv_db.seg_permisos_t n
    where n.id_permiso not in (select rn.id_permiso from inv_db.seg_det_permisos_roles_t rn where rn.id_rol =  p_id_rol)
      and n.id_permiso in(SELECT REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)FROM DUAL
                          CONNECT BY REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL)IS NOT NULL);

    p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
    commit;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end modificar;

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
  ) is
    v_error varchar2(4000);
  begin
    delete from inv_db.seg_det_permisos_roles_t pr
    where pr.id_rol = p_id_rol;

    delete from inv_db.seg_roles_t r
    where r.id_rol = p_id_rol;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('borrado');
  exception when others then
    v_error := sqlerrm||chr(10)||dbms_utility.format_error_backtrace;
    rollback;
    if (v_error like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||v_error;
    end if;
  end borrar;

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
  ) is
  begin
    delete from inv_db.seg_det_permisos_roles_t dpr
    where dpr.id_rol = p_id_rol;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('revocados');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end revocar_permisos;

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
  ) is
  begin
    delete from inv_db.seg_det_roles_usuarios_t dru
    where dru.id_rol = p_id_rol;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('removidos');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end remover_usuarios;

end seg_roles_pkg;

