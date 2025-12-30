create or replace force view inv_db.seg_usuarios_menues_v as
select up.id_usuario
       , s.secuencia secuencia_seccion, s.seccion, s.icono icono_seccion
       , p.secuencia secuencia_permiso, pag.id_pagina, pag.opcion_menu permiso, p.direccion_electronica, p.icono icono_permiso
  from inv_db.seg_usuarios_permisos_v up
  join seg_permisos_t p on p.id_permiso=up.id_permiso
  join man_paginas_t pag on pag.id_permiso_consultar=p.id_permiso
  join seg_secciones_t s on s.id_seccion=p.id_seccion and s.estado_registro='A'
where p.id_seccion is not null or p.secuencia is not null or p.icono is not null
;

