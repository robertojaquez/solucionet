create or replace package body inv_db.seg_det_roles_usuarios_pkg as
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
  ) is
    v_conteo  int;
  begin
    select count(*)
    into v_conteo
    from inv_db.seg_usuarios_v
    where id_usuario=upper(p_id_usuario);

    if (v_conteo=0) then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('no_existe');
    else
      select count(*)
      into v_conteo
      from inv_db.seg_det_roles_usuarios_t ru
      where ru.id_usuario = upper(p_id_usuario)
      and ru.administrador='S';

      if (v_conteo>0) then
        p_resultado := 'ER|'||man_formatear_pkg.mensaje('es_admin');
      else
        insert into inv_db.seg_det_roles_usuarios_t (
          id_usuario,
          administrador,
          id_rol,
          agregado_por,
          agregado_en,
          estado_registro
        ) values (
          upper(p_id_usuario),
          'N',
          p_id_rol,
          p_id_usuario_procesa,
          sysdate,
          'A'
        );

        update inv_db.seg_roles_t r
        set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
        where id_rol = p_id_rol;

        p_resultado := 'OK|'||man_formatear_pkg.mensaje('agregado');
        commit;
      end if;
    end if;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end agregar;

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
  ) is
    v_conteo  int;
  begin
    select count(*)
    into v_conteo
    from inv_db.seg_usuarios_v
    where id_usuario=upper(p_id_usuario);

    if (v_conteo=0) then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('no_existe');
    else
      select count(*)
      into v_conteo
      from inv_db.seg_det_roles_usuarios_t ru
      where ru.id_usuario = upper(p_id_usuario)
      and ru.administrador='S';

      if (v_conteo>0) then
        p_resultado := 'ER|'||man_formatear_pkg.mensaje('es_admin');
      else
        update inv_db.seg_det_roles_usuarios_t set
          id_usuario                    = upper(p_id_usuario),
          id_rol                        = p_id_rol,
          modificado_por                = p_id_usuario_procesa,
          modificado_en                 = sysdate,
          estado_registro               = p_estado_registro
        where id_rol_usuario = p_id_rol_usuario;

        update inv_db.seg_roles_t r
        set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
        where id_rol = p_id_rol;
        p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
        commit;
      end if;
    end if;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end modificar;

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
  ) is
    m_id_rol  int;
  begin
    select id_rol
    into m_id_rol
    from inv_db.seg_det_roles_usuarios_t d
    where d.id_rol_usuario = p_id_rol_usuario;

    delete from inv_db.seg_det_roles_usuarios_t
    where id_rol_usuario = p_id_rol_usuario;

    update inv_db.seg_roles_t r
    set r.modificado_por = p_id_usuario_procesa, r.modificado_en = sysdate
    where id_rol = m_id_rol;

    commit;
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('borrado');
  exception when others then
    if (sqlerrm like '%child record found%') then
      p_resultado := 'ER|'||man_formatear_pkg.mensaje('fk_error');
    else
      p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
    end if;
  end borrar;

end seg_det_roles_usuarios_pkg;
