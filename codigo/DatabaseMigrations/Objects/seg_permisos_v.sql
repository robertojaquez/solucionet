create or replace force view inv_db.seg_permisos_v as
select a."ID_PERMISO",a."PERMISO",a."DIRECCION_ELECTRONICA",a."ICONO",a."SECUENCIA",a."ID_SECCION",a."AGREGADO_POR",a."AGREGADO_EN",a."MODIFICADO_POR",a."MODIFICADO_EN",a."ESTADO_REGISTRO"
   , a.agregado_por||' en '||to_char(a.agregado_en,'dd/mm/yyyy hh:mi:ss AM') agregado_por_en
   , case when a.modificado_por is null then null else a.modificado_por||' en '||to_char(a.modificado_en,'dd/mm/yyyy hh:mi:ss AM') end modificado_por_en
   , decode(a.estado_registro,'A','Activo','I','Inactivo') descripcion_estatus
  from inv_db.seg_permisos_t a
;

