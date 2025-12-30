create or replace package body inv_db.seg_det_permisos_roles_pkg as
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
  ) is
  begin
    insert into inv_db.seg_det_permisos_roles_t( id_rol,id_permiso,agregado_por,agregado_en,estado_registro)
    select p_id_rol, permisos.permiso,p_id_usuario_procesa,sysdate,'A'
    from ( SELECT REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL) permiso FROM DUAL
           CONNECT BY REGEXP_SUBSTR (p_permisos, '[^,]+', 1,LEVEL) IS NOT NULL
    ) permisos;

    update inv_db.seg_roles_t r
    set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
    where r.id_rol = p_id_rol;

    p_resultado := 'OK|'||man_formatear_pkg.mensaje('agregado');
    commit;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end agregar;

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
  ) is
  begin
    for registro in (select * from inv_db.seg_det_permisos_roles_v where id_registro=p_id_registro)
    loop
      -- consultar
      if (p_puede_consultar='S' and registro.puede_consultar='N') then
        insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
        values (p_id_rol, registro.id_consultar, p_id_usuario_procesa, sysdate, 'A');
      elsif (p_puede_consultar='N' and registro.puede_consultar='S') then
        delete from inv_db.seg_det_permisos_roles_t
        where id_rol = p_id_rol and id_permiso = registro.id_consultar;
      end if;
      -- agregar
      if (p_puede_agregar='S' and registro.puede_agregar='N') then
        insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
        values (p_id_rol, registro.id_agregar, p_id_usuario_procesa, sysdate, 'A');
      elsif (p_puede_agregar='N' and registro.puede_agregar='S') then
        delete from inv_db.seg_det_permisos_roles_t
        where id_rol = p_id_rol and id_permiso = registro.id_agregar;
      end if;
      -- modificar
      if (p_puede_modificar='S' and registro.puede_modificar='N') then
        insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
        values (p_id_rol, registro.id_modificar, p_id_usuario_procesa, sysdate, 'A');
      elsif (p_puede_modificar='N' and registro.puede_modificar='S') then
        delete from inv_db.seg_det_permisos_roles_t
        where id_rol = p_id_rol and id_permiso = registro.id_modificar;
      end if;
      -- borrar
      if (p_puede_borrar='S' and registro.puede_borrar='N') then
        insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
        values (p_id_rol, registro.id_borrar, p_id_usuario_procesa, sysdate, 'A');
      elsif (p_puede_borrar='N' and registro.puede_borrar='S') then
        delete from inv_db.seg_det_permisos_roles_t
        where id_rol = p_id_rol and id_permiso = registro.id_borrar;
      end if;
      -- ejecutar
      if (p_puede_ejecutar='S' and registro.puede_ejecutar='N') then
        insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
        values (p_id_rol, registro.id_ejecutar, p_id_usuario_procesa, sysdate, 'A');
      elsif (p_puede_ejecutar='N' and registro.puede_ejecutar='S') then
        delete from inv_db.seg_det_permisos_roles_t
        where id_rol = p_id_rol and id_permiso = registro.id_ejecutar;
      end if;
    end loop;

    update inv_db.seg_roles_t r
    set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
    where r.id_rol = p_id_rol;

    p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
    commit;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end modificar;

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
  ) is
    v_id_rol  int;
    v_id_con  int;
    v_id_add  int;
    v_id_mod  int;
    v_id_del  int;
    v_id_exe  int;
  begin
    select id_rol, id_consultar, id_agregar, id_modificar, id_borrar, id_ejecutar
    into v_id_rol, v_id_con, v_id_add, v_id_mod, v_id_del, v_id_exe
    from inv_db.seg_det_permisos_roles_v
    where id_registro=p_id_registro;

    if (v_id_con is not null) then
      delete from inv_db.seg_det_permisos_roles_t dpr where dpr.id_rol=v_id_rol and dpr.id_permiso = v_id_con;
    end if;
    if (v_id_add is not null) then
      delete from inv_db.seg_det_permisos_roles_t dpr where dpr.id_rol=v_id_rol and dpr.id_permiso = v_id_add;
    end if;
    if (v_id_mod is not null) then
      delete from inv_db.seg_det_permisos_roles_t dpr where dpr.id_rol=v_id_rol and dpr.id_permiso = v_id_mod;
    end if;
    if (v_id_del is not null) then
      delete from inv_db.seg_det_permisos_roles_t dpr where dpr.id_rol=v_id_rol and dpr.id_permiso = v_id_del;
    end if;
    if (v_id_exe is not null) then
      delete from inv_db.seg_det_permisos_roles_t dpr where dpr.id_rol=v_id_rol and dpr.id_permiso = v_id_exe;
    end if;

    update inv_db.seg_roles_t r
    set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
    where r.id_rol = v_id_rol;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('borrado');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end borrar;

end seg_det_permisos_roles_pkg;

