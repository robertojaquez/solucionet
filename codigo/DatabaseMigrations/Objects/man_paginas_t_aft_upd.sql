create or replace trigger inv_db.man_paginas_t_aft_upd
after update on inv_db.man_paginas_t
for each row
/**
  * Autor    : Roberto Jaquez & Fausto Montero
  * Fecha    : 21/10/2024
  * Objetivo : este trigger mantiene sincronizados el titulo de una página y sus permisos
*/
begin
  if (:new.titulo <> :old.titulo) then
    update inv_db.seg_permisos_t p set p.permiso = :new.titulo||': Consultar' where p.id_permiso = nvl(:new.id_permiso_consultar,-1);
    update inv_db.seg_permisos_t p set p.permiso = :new.titulo||': Agregar'   where p.id_permiso = nvl(:new.id_permiso_agregar  ,-1);
    update inv_db.seg_permisos_t p set p.permiso = :new.titulo||': Modificar' where p.id_permiso = nvl(:new.id_permiso_modificar,-1);
    update inv_db.seg_permisos_t p set p.permiso = :new.titulo||': Borrar'    where p.id_permiso = nvl(:new.id_permiso_borrar   ,-1);
    for acciones in (select * from inv_db.man_det_acciones_paginas_t where id_pagina = :new.id_pagina)
    loop
      update inv_db.seg_permisos_t p
      set p.permiso = :new.titulo||': '||acciones.accion
      where p.id_permiso = acciones.id_permiso;
    end loop;
  end if;
end man_paginas_t_aft_upd;

