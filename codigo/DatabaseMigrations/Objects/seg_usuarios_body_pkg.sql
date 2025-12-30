create or replace package body inv_db.seg_usuarios_pkg as
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
    * @p_id_usuario: ID del usuario en directa relación con la tabla de usuarios del SUIR
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
  ) is
    v_conteo int;
    v_id_usuario varchar2(100) := upper(p_id_usuario);
  begin
    if (p_administrador='S') then
      -- ver si ya era administrador
      select count(*)
      into v_conteo
      from inv_db.seg_det_roles_usuarios_t
      where id_usuario = v_id_usuario
      and administrador='A';

      if (v_conteo=0) then
        -- no era administrador, borrar cualquier rol que tuviese asignado
        delete from inv_db.seg_det_roles_usuarios_t
        where id_usuario = v_id_usuario;

        -- insertarlo como administrador
        insert into inv_db.seg_det_roles_usuarios_t (id_usuario, administrador, id_rol, agregado_por, agregado_en, estado_registro) 
        values (v_id_usuario, 'S', null, p_id_usuario_procesa, sysdate, 'A');
      end if;
      p_resultado := 'OK|'||man_formatear_pkg.mensaje('agregado');
      commit;
    else
      -- quitarle los roles no marcados
      delete from inv_db.seg_det_roles_usuarios_t
      where id_usuario = v_id_usuario
      and (administrador='S' or p_roles not like '%,'||nvl(id_rol,-1)||',%');
        
      -- agregarles los roles marcados
      insert into inv_db.seg_det_roles_usuarios_t (id_usuario, administrador, id_rol, agregado_por, agregado_en, estado_registro)
      select v_id_usuario,'N',id_rol,p_id_usuario_procesa,sysdate,'A'
      from inv_db.seg_roles_t r
      where p_roles like '%,'||r.id_rol||',%'
      and r.id_rol not in(select x.id_rol from inv_db.seg_det_roles_usuarios_t x where x.id_usuario = v_id_usuario and x.id_rol is not null);

      p_resultado := 'OK|'||man_formatear_pkg.mensaje('agregado');
      commit;
    end if;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm||dbms_utility.format_error_backtrace;
  end agregar;

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
  ) is
    v_conteo int;
    v_id_usuario varchar2(100) := upper(p_id_usuario);
  begin
    if (p_administrador='S') then
      -- ver si ya era administrador
      select count(*)
      into v_conteo
      from inv_db.seg_det_roles_usuarios_t
      where id_usuario = v_id_usuario
      and administrador='A';

      if (v_conteo=0) then
        -- no era administrador, borrar cualquier rol que tuviese asignado
        delete from inv_db.seg_det_roles_usuarios_t
        where id_usuario = v_id_usuario;

        -- insertarlo como administrador
        insert into inv_db.seg_det_roles_usuarios_t (id_usuario, administrador, id_rol, agregado_por, agregado_en, estado_registro) 
        values (v_id_usuario, 'S', null, p_id_usuario_procesa, sysdate, 'A');
      end if;
      p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
      commit;
    else
      -- quitarle los roles no marcados
      delete from inv_db.seg_det_roles_usuarios_t
      where id_usuario = v_id_usuario
      and (administrador='S' or p_roles not like '%,'||nvl(id_rol,-1)||',%');
        
      -- agregarles los roles marcados
      insert into inv_db.seg_det_roles_usuarios_t (id_usuario, administrador, id_rol, agregado_por, agregado_en, estado_registro)
      select v_id_usuario,'N',id_rol,p_id_usuario_procesa,sysdate,'A'
      from inv_db.seg_roles_t r
      where p_roles like '%,'||r.id_rol||',%'
      and r.id_rol not in(select x.id_rol from inv_db.seg_det_roles_usuarios_t x where x.id_usuario = v_id_usuario and x.id_rol is not null);

      p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
      commit;
    end if;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm||dbms_utility.format_error_backtrace;
  end modificar;

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
  ) is
  begin
    -- acciones que se desean realizar sobre el registro
    delete from inv_db.seg_det_roles_usuarios_t
    where id_usuario = p_id_usuario;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('revocado');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end revocar_acceso;

end seg_usuarios_pkg;
