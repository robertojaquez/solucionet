create or replace force view inv_db.seg_det_permisos_v as
with grupos as (
  select nvl(s.secuencia,9) secuencia_seccion, s.seccion,
         nvl(p.secuencia,9) secuencia_grupo, substr(p.permiso,1,instr(p.permiso,': ')-1) grupo,
         p.id_permiso id_consultar, null id_ejecutar
  from inv_db.seg_secciones_t s
  join inv_db.seg_permisos_t p on p.id_seccion=s.id_seccion and p.permiso like '%: Consultar%'
  union all
  select nvl(s.secuencia,9) secuencia_seccion, s.seccion,
         nvl(p.secuencia,9) secuencia_grupo, e.permiso grupo, null id_consultar, e.id_permiso id_ejecutar
  from inv_db.seg_secciones_t s
  join inv_db.seg_permisos_t p on p.id_seccion=s.id_seccion and p.permiso like '%: Consultar%'
  join inv_db.seg_permisos_t e on substr(e.permiso,1,instr(e.permiso,': ')-1) = substr(p.permiso,1,instr(p.permiso,': ')-1)
   and ': Consultar,: Agregar,: Modificar,: Borrar' not like '%'||substr(e.permiso,instr(e.permiso,': '))||'%'
)
select g.secuencia_seccion, g.seccion,
       g.secuencia_grupo, g.grupo,
       g.id_consultar,
       a.id_permiso id_agregar,
       m.id_permiso id_modificar,
       b.id_permiso id_borrar,
       g.id_ejecutar
from grupos g
left join inv_db.seg_permisos_t a on a.permiso = g.grupo||': Agregar'
left join inv_db.seg_permisos_t m on m.permiso = g.grupo||': Modificar'
left join inv_db.seg_permisos_t b on b.permiso = g.grupo||': Borrar'
order by g.secuencia_seccion,g.seccion,g.secuencia_grupo,g.grupo
;

