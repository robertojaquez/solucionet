create table inv_db.MAN_SESIONES_T
(
  id_sesion  VARCHAR2(100) not null,
  id_usuario VARCHAR2(100) not null,
  id_pagina  NUMBER(10),
  llave      VARCHAR2(100) not null,
  valor      VARCHAR2(2000),
  fecha      DATE default sysdate not null,
  documento  BLOB
)

;
comment on table inv_db.MAN_SESIONES_T
  is 'Variables del framework disponibles para un usuario mientras usa una página'
;
comment on column inv_db.MAN_SESIONES_T.id_sesion
  is 'Id del registro'
;
comment on column inv_db.MAN_SESIONES_T.id_usuario
  is 'Id del usuario de la sesión'
;
comment on column inv_db.MAN_SESIONES_T.id_pagina
  is 'Id de la página actual'
;
comment on column inv_db.MAN_SESIONES_T.llave
  is 'Nombre de la variable de sesión'
;
comment on column inv_db.MAN_SESIONES_T.valor
  is 'Valor de la variable'
;
comment on column inv_db.MAN_SESIONES_T.fecha
  is 'Fecha en que se guardó la variable'
;
comment on column inv_db.MAN_SESIONES_T.documento
  is 'Documento cargado'
;

