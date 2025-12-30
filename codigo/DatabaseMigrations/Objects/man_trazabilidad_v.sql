create or replace force view inv_db.man_trazabilidad_v as
select t.id_trazabilidad,
       p.id_pagina,
       p.titulo pagina,
       t.accion,
       t.id_registro,
       t.id_usuario,
       trunc(t.fecha) fecha,
       to_char(t.fecha,'hh:mi:ss am') hora,
       t.id_usuario||' en '||to_char(t.fecha,'dd/mm/yyyy hh:mi:ss AM') realizado_por,
       inv_db.man_formatear_pkg.detalle_trazabilidad(t.accion,t.id_trazabilidad) detalle
from inv_db.man_trazabilidad_t t
join inv_db.man_paginas_t p on p.id_pagina=t.id_pagina
;

