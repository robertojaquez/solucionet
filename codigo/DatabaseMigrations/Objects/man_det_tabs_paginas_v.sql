create or replace force view inv_db.man_det_tabs_paginas_v as
select up.id_usuario, p.id_maestro, p.id_pagina, p.plural, p.secuencia
  from seg_usuarios_permisos_v up
  join man_paginas_t p on p.id_permiso_consultar=up.id_permiso and id_maestro is not null
;

