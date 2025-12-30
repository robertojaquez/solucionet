create or replace force view inv_db.seg_roles_v as
select a."ID_ROL",a."ROL",a."AGREGADO_POR",a."AGREGADO_EN",a."MODIFICADO_POR",a."MODIFICADO_EN",a."ESTADO_REGISTRO"
       , a.agregado_por||' en '||to_char(a.agregado_en,'dd/mm/yyyy hh:mi:ss AM') agregado_por_en
       , case when a.modificado_por is null then null else a.modificado_por||' en '||to_char(a.modificado_en,'dd/mm/yyyy hh:mi:ss AM') end modificado_por_en
       , decode(a.estado_registro,'A','Activo','I','Inactivo') descripcion_estatus
       ,(select  LISTAGG(pr.id_permiso,',') WITHIN GROUP( ORDER BY pr.id_permiso) from inv_db.seg_det_permisos_roles_t pr where pr.id_rol = a.id_rol GROUP BY a.id_rol) as permisos
       ,(select  LISTAGG(ru.id_usuario,',') WITHIN GROUP( ORDER BY ru.id_usuario) from inv_db.seg_det_roles_usuarios_t ru where ru.id_rol = a.id_rol GROUP BY a.id_rol) as usuarios
  from inv_db.seg_roles_t a
;

