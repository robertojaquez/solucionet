create or replace view inv_db.seg_usuarios_permisos_v as
select dru.id_usuario, p.id_permiso
  from inv_db.seg_det_roles_usuarios_t dru
  join seg_permisos_t p on p.estado_registro='A'
where dru.administrador='S' and dru.estado_registro='A'
union
select dru.id_usuario, p.id_permiso
  from seg_det_roles_usuarios_t dru
  join seg_roles_t r                on r.estado_registro  ='A' and r.id_rol=dru.id_rol
  join seg_det_permisos_roles_t dpr on dpr.estado_registro='A' and dpr.id_rol=r.id_rol
  join seg_permisos_t           p   on p.estado_registro  ='A' and p.id_permiso=dpr.id_permiso
where dru.administrador='N' and dru.estado_registro='A'
;