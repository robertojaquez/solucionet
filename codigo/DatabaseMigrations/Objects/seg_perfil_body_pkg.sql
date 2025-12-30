create or replace package body inv_db.seg_perfil_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo del registro del perfil de un usuario
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar un registro de la tabla seg_perfil_t (perfil del usuario).
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_usuario: id del usuario que será modificado
    * @p_email: email del usuario
    * @p_numero_movil: numero de movil del usuario
    * @p_firma: firma del usuario
    * @p_resultado: retorna OK|mensaje, ER|mensaje1|mensaje2|etc o EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_usuario                     in  inv_db.seg_perfil_v.id_usuario%type,
    p_email                          in  inv_db.seg_perfil_v.email%type,
    p_numero_movil                   in  inv_db.seg_perfil_v.numero_movil%type,
    p_firma                          in  inv_db.seg_perfil_v.firma%type,
    p_resultado                      out varchar2
  ) is
  begin
    update rrhh_db.rh_colaboradores_t
    set firma            = p_firma
      , email            = p_email
      , numero_movil     = p_numero_movil
      , modificado_por   = p_id_usuario_procesa
      , modificado_en    = sysdate
    where usuario_dominio = p_id_usuario;
          
    p_resultado := 'OK|'||man_formatear_pkg.mensaje('modificado');
    commit;
  exception when others then
    p_resultado := 'EX|'||man_formatear_pkg.mensaje('excepcion')||chr(10)||sqlerrm||chr(10)||dbms_utility.format_error_backtrace;
  end modificar;

end seg_perfil_pkg;
