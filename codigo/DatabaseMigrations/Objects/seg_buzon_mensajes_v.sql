create or replace force view inv_db.seg_buzon_mensajes_v as
select a."ID_BUZON_MENSAJE",a."ID_USUARIO",a."ASUNTO",a."MENSAJE",a."ENVIADO_EN",a."LEIDO_EN",a."LEIDO"
  ,decode(a.leido,'S','drafts','N','inbox') icono_estatus
  from inv_db.SEG_BUZON_MENSAJES_T a
;

