create or replace force view inv_db.seg_det_roles_usuarios_mchk_v as
select u.ID_usuario id_registro,
       r.ID_rol id_detalle,
       r.rol DESCRIPCION,
       rownum secuencia,
       case when er.ID_rol is null then 'N' else 'S' end seleccionado
from inv_db.seg_usuarios_v u
join inv_db.seg_roles_t r on 1=1
left join inv_db.seg_det_roles_usuarios_t er
  on er.ID_usuario = u.id_usuario
 and er.ID_rol = r.ID_rol
 and er.administrador='N'
;

