create or replace view inv_db.seg_det_roles_usuarios_v as
select a."ID_ROL_USUARIO",a."ID_USUARIO",a."ADMINISTRADOR",a."ID_ROL",a."AGREGADO_POR",a."AGREGADO_EN",a."MODIFICADO_POR",a."MODIFICADO_EN",a.estado_registro
       , u.nombre_usuario
       , r.rol
       , decode(a.estado_registro,'A','Activo','I','Inactivo') descripcion_estatus
       , a.agregado_por||' en '||to_char(a.agregado_en,'dd/mm/yyyy hh:mi:ss am') agregado_poren
       , case when a.modificado_por is null then null else a.modificado_por||' en '||to_char(a.modificado_en,'dd/mm/yyyy hh:mi:ss am') end modificado_poren
  from inv_db.seg_det_roles_usuarios_t a
  join inv_db.seg_usuarios_v u on u.id_usuario=a.id_usuario
  left join inv_db.seg_roles_t r on r.id_rol=a.id_rol
  where a.administrador='N'
;