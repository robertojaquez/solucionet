create or replace force view inv_db.seg_usuarios_pendientes_v as
select up.id_usuario, x.id_pagina, x.pendientes_titulo, x.pendientes_sql
from seg_usuarios_permisos_v up
join seg_permisos_t p on p.id_permiso=up.id_permiso
join man_paginas_t x on x.id_permiso_consultar = p.id_permiso and x.pendientes_sql is not null and x.pendientes_titulo is not null
;

