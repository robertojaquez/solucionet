declare
  v_id_rol int;
  v_usuario varchar2(15) := 'OPERACIONES';
  v_fecha   date         := sysdate;
  v_estado  char(1)      := 'A'; 
begin
  -- Seguridad ----------------------------------------------------------------------------------------------------------
  insert into inv_db.seg_roles_t (rol, agregado_por, agregado_en, estado_registro) 
  values ('Seguridad',v_usuario, v_fecha, v_estado) 
  returning id_rol into v_id_rol;
  
  insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
  select v_id_rol, p.id_permiso, v_usuario, v_fecha, v_estado
  from inv_db.seg_permisos_t p
  where p.permiso like 'Usuarios del Sistema:%'
     or p.permiso like 'Roles del Sistema:%'
     or p.permiso like 'Permisos por Rol del Sistema:%'
     or p.permiso like 'Usuarios por Rol del Sistema:%'
     or p.permiso like 'Permisos del Sistema:%'
     or p.permiso like 'Trazabilidad de cambios:%';

  -- Consultor ----------------------------------------------------------------------------------------------------------
  insert into inv_db.seg_roles_t (rol, agregado_por, agregado_en, estado_registro) 
  values ('Consultor',v_usuario, v_fecha, v_estado) 
  returning id_rol into v_id_rol;

  insert into inv_db.seg_det_permisos_roles_t (id_rol, id_permiso, agregado_por, agregado_en, estado_registro)
  select v_id_rol, p.id_permiso, v_usuario, v_fecha, v_estado
  from inv_db.seg_permisos_t p
  where p.permiso like '%: Consultar';
     
  commit;
exception when others then
  rollback;
  raise_application_error(-20000,sqlerrm);
end;
