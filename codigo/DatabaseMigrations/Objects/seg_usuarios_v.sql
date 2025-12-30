create or replace view inv_db.seg_usuarios_v as
select a.usuario_dominio id_usuario, a.numero_movil, a.email, a.firma, a.agregado_por, a.agregado_en, a.modificado_por, a.modificado_en, a.estado_registro,
       initcap(trim(a.nombres||' '||a.apellido_1||' '||a.apellido_2)) nombre_usuario,
       case when x.administrador is null then 'No' when x.administrador='S' then 'Sí' else 'No' end as administrador,
      (select  LISTAGG(pr.id_rol,',') WITHIN GROUP( ORDER BY pr.id_rol) from inv_db.seg_det_roles_usuarios_t pr where pr.id_usuario = a.usuario_dominio GROUP BY a.usuario_dominio) as roles
from rrhh_db.rh_colaboradores_t a
left join inv_db.seg_det_roles_usuarios_t x on x.id_usuario=a.usuario_dominio and x.administrador='S'
where a.estado_registro='A'
and a.usuario_dominio in(select ru.id_usuario from inv_db.seg_det_roles_usuarios_t ru where ru.estado_registro='A')
;