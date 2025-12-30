create table inv_db.man_log_accesos_t (
  id_usuario          varchar2(100) not null,
  fecha               date not null,
  accion              varchar2(250) not null,
  cantidad            number(10) not null,
  constraint pk_man_log_accesos_t primary key (id_usuario,fecha,accion)
)
;
comment on table  inv_db.man_log_accesos_t             is 'Log de acceso de usuarios a las opciones del sistema'
;
comment on column inv_db.man_log_accesos_t.id_usuario  is 'Id del usuario que accedió al sistema'
;
comment on column inv_db.man_log_accesos_t.fecha       is 'Fecha en que sucedió el acceso'
;
comment on column inv_db.man_log_accesos_t.accion      is 'Acción que realizó el usuario'
;
comment on column inv_db.man_log_accesos_t.cantidad    is 'Cantidad de veces que el usuario realizó dicha accion en dicha fecha'
;