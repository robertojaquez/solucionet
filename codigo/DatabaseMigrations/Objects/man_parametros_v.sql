create or replace force view inv_db.man_parametros_v as
select a."ID_PARAMETRO",a."PARAMETRO",a."DESCRIPCION",a."VALOR_ACTUAL",a."AGREGADO_POR",a."AGREGADO_EN",a."MODIFICADO_POR",a."MODIFICADO_EN",a."ESTADO_REGISTRO"
       , decode(a.estado_registro,'A','Activo','I','Inactivo') descripcion_estado_registro
       , case when a.agregado_por       is not null then a.agregado_por      ||' en '||to_char(a.agregado_en      ,'dd/mm/yyyy hh:mi:ss am') else null end agregado_por_en
       , case when a.modificado_por     is not null then a.modificado_por    ||' en '||to_char(a.modificado_en    ,'dd/mm/yyyy hh:mi:ss am') else null end modificado_por_en
  from inv_db.man_parametros_t a
;

