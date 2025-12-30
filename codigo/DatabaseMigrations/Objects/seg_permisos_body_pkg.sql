create or replace package body inv_db.seg_permisos_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros de permisos (seg_permisos_t)
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Activar un registro de la tabla seg_permisos_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_permiso: id del permiso que será activado
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure activar(
    p_id_usuario_procesa             in  varchar2,
    p_id_permiso                     in  seg_permisos_v.id_permiso%type,
    p_resultado                      out varchar2
  ) is
    v_conteo      integer;
  begin
    select count(*)
      into v_conteo
      from inv_db.seg_permisos_t p
     where p.id_permiso = p_id_permiso
      and p.estado_registro = 'A';

     if v_conteo > 0 then
         p_resultado := 'ER|'||man_formatear_pkg.mensaje('ya activo');
     else
         update inv_db.seg_permisos_t p set
                 p.estado_registro = 'A',
                 p.modificado_por = p_id_usuario_procesa,
                 p.modificado_en = sysdate
            where p.id_permiso =   p_id_permiso ;

         commit;
         p_resultado := 'OK|'||man_formatear_pkg.mensaje('activado');
     end if;

   exception when others then
       p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
   end activar;

  /**
   * Autor    : Roberto Jaquez & Fausto Montero
   * Fecha    : 21/10/2024
   * Objetivo : Inactivar un registro de la tabla seg_permisos_t.
   * @p_id_usuario_procesa: Id del usuario logueado
   * @p_id_permiso: id del permiso que será inactivado
   * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure inactivar(
    p_id_usuario_procesa             in  varchar2,
    p_id_permiso                     in  seg_permisos_v.id_permiso%type,
    p_resultado                      out varchar2
  ) is
    v_conteo      integer;
  begin
    select count(*)
      into v_conteo
      from inv_db.seg_permisos_t p
     where p.id_permiso = p_id_permiso
      and p.estado_registro = 'I';

     if v_conteo > 0 then
         p_resultado := 'ER|'||man_formatear_pkg.mensaje('ya inactivo');
     else
         update inv_db.seg_permisos_t p set
                 p.estado_registro = 'I',
                 p.modificado_por = p_id_usuario_procesa,
                 p.modificado_en = sysdate
            where p.id_permiso =   p_id_permiso ;

         commit;
         p_resultado := 'OK|'||man_formatear_pkg.mensaje('inactivado');
     end if;

  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm;
  end inactivar;

end seg_permisos_pkg;

