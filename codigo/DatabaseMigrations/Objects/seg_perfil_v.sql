create or replace force view inv_db.seg_perfil_v as
select a.usuario_dominio id_usuario 
     , initcap(trim(a.nombres||' '||a.apellido_1||' '||a.apellido_2)) nombre_usuario
     , a.numero_movil, a.email, a.firma
     , a.agregado_por||' en '||to_char(a.agregado_en,'dd/mm/yyyy hh:mi:ss AM') agregado_por_en
     , case when a.modificado_por is null then null else a.modificado_por||' en '||to_char(a.modificado_en,'dd/mm/yyyy hh:mi:ss AM') end actualizado_por_en
  from rrhh_db.rh_colaboradores_t a
  where a.estado_registro='A'
  ;
