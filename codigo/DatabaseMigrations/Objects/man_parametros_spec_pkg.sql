create or replace package inv_db.man_parametros_pkg as
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de los registros parametros.
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Modificar un registro de la tabla man_parametros_t.
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_id_parametro      : Id del registro
    * @p_valor_actual      : Valor actual
    * @p_resultado         : retorna OK|mensaje, EX|mensaje
  */
  procedure modificar(
    p_id_usuario_procesa             in  varchar2,
    p_id_parametro                   in  man_parametros_v.id_parametro%type,
    p_valor_actual                   in  man_parametros_v.valor_actual%type,
    p_resultado                      out varchar2
  );

end man_parametros_pkg;

