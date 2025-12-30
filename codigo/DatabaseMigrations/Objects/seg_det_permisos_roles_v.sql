create or replace force view inv_db.seg_det_permisos_roles_v as
with grupos as (
  select distinct r.id_rol, r.rol,
         case
         when p.permiso like '%: Consultar' or p.permiso like '%: Agregar' or p.permiso like '%: Modificar' or p.permiso like '%: Borrar'
         then substr(p.permiso,1,instr(p.permiso,': ')-1)
         else p.permiso
         end permiso
  from inv_db.seg_roles_t r
  join inv_db.seg_det_permisos_roles_t dpr on dpr.id_rol=r.id_rol
  join inv_db.seg_permisos_t p on p.id_permiso=dpr.id_permiso
)
select g.id_rol||'-'||g.permiso id_registro,
       g.id_rol, g.rol, g.permiso,
       pc.id_permiso id_consultar, pa.id_permiso id_agregar, pm.id_permiso id_modificar, pb.id_permiso id_borrar, px.id_permiso id_ejecutar,
       case when pc.id_permiso is null then CHR(8) when dpr_c.id_permiso_rol is null then 'N' else 'S' end puede_consultar,
       case when pa.id_permiso is null then CHR(8) when dpr_a.id_permiso_rol is null then 'N' else 'S' end puede_agregar,
       case when pm.id_permiso is null then CHR(8) when dpr_m.id_permiso_rol is null then 'N' else 'S' end puede_modificar,
       case when pb.id_permiso is null then CHR(8) when dpr_b.id_permiso_rol is null then 'N' else 'S' end puede_borrar,
       case when px.id_permiso is null then CHR(8) when dpr_x.id_permiso_rol is null then 'N' else 'S' end puede_ejecutar,
       ','||pc.id_permiso||','||pa.id_permiso||','||pm.id_permiso||','||pb.id_permiso||','||px.id_permiso||',' as permisos
from grupos g
left join inv_db.seg_permisos_t pc on pc.permiso = g.permiso||': Consultar'
left join inv_db.seg_permisos_t pa on pa.permiso = g.permiso||': Agregar'
left join inv_db.seg_permisos_t pm on pm.permiso = g.permiso||': Modificar'
left join inv_db.seg_permisos_t pb on pb.permiso = g.permiso||': Borrar'
left join inv_db.seg_permisos_t px on px.permiso = g.permiso
left join inv_db.seg_det_permisos_roles_t dpr_c on dpr_c.id_rol=g.id_rol and dpr_c.id_permiso=pc.id_permiso
left join inv_db.seg_det_permisos_roles_t dpr_a on dpr_a.id_rol=g.id_rol and dpr_a.id_permiso=pa.id_permiso
left join inv_db.seg_det_permisos_roles_t dpr_m on dpr_m.id_rol=g.id_rol and dpr_m.id_permiso=pm.id_permiso
left join inv_db.seg_det_permisos_roles_t dpr_b on dpr_b.id_rol=g.id_rol and dpr_b.id_permiso=pb.id_permiso
left join inv_db.seg_det_permisos_roles_t dpr_x on dpr_x.id_rol=g.id_rol and dpr_x.id_permiso=px.id_permiso
;

