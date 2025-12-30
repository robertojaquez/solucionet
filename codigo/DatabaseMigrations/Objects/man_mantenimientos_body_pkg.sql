create or replace package body inv_db.man_mantenimientos_pkg is
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para la generacion dinamica de paginas
  */

  -- propiedades comunes de la pagina actual-----------------
  g_resultado          clob;
  g_id_sesion          inv_db.man_sesiones_t.id_sesion%type;
  g_id_usuario_procesa inv_db.seg_usuarios_v.id_usuario%type;
  g_id_inventario      int;
  g_pagina             t_pagina;
  g_maestro            t_pagina;
  g_reporte            a_reporte;
  g_puede_consultar    char(1);
  g_puede_agregar      char(1);
  g_puede_modificar    char(1);
  g_puede_borrar       char(1);
  g_puede_ver_tabs     int;
  g_pag_solo_lectura   char(1);
  g_registros          varchar2(1000);
  g_columnas           t_columnas;
  g_trazabilidad       char(1);
  g_filtros            t_filtros;
  g_reportes           t_reportes;
  g_reportes_multi     int;
  g_reportes_uni       int;
  g_acciones           t_acciones;
  g_registro           t_formulario;
  g_tabs               t_tabs;
  g_formulario         t_formulario;
  g_empty_formulario   t_formulario;
  g_valores_parametros clob;

  g_select2_params     varchar2(1000) := '{width: ''element''}';

  -- hasta aqui las propiedades comunes-----------------------
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Guardar log de acceso
    * @p_id_usuario: id del usuario que accedió a una opcion del sistema
    * @p_accion: accion que realizó el usuario
  */
  procedure log_acceso(
    p_id_usuario inv_db.man_log_accesos_t.id_usuario%type,
    p_accion     inv_db.man_log_accesos_t.accion%type
  ) is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    merge into inv_db.man_log_accesos_t l
    using (select p_id_usuario id_usuario, p_accion accion from dual) a
    on (l.id_usuario=a.id_usuario and l.fecha=trunc(sysdate) and l.accion=a.accion)
    when matched     then update set cantidad=cantidad+1
    when not matched then insert values (a.id_usuario, trunc(sysdate), a.accion,1);
    commit;
  end;
  
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : agrega una linea en el html a renderizar
    * @p_texto: texto o etiquetas html a renderizar
  */
  procedure add(
    p_texto in clob
  ) is
  begin
    g_resultado := g_resultado||chr(13)||p_texto;
  end;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : agrega una linea en el html a renderizar para fines de debugeo
    * @p_texto: texto o etiquetas html a renderizar para fines de debugeo
  */
  procedure debug(
    p_texto in clob
  ) is
  begin
    add(p_texto);

  end;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : agrega al html una alerta modal que no permite usal la pagina hasta que se presione un botón
    * @p_texto: texto de la alerta
    * @p_icon: icono/tipo de alerta: puede ser success,error,warning,question, entre otros
  */
  function alert(
    p_texto in varchar2,
    p_icon in varchar2
  ) return varchar2 is
    m_bullet varchar2(10) := '\u2022 ';
    m_texto varchar2(32000);
  begin
    -- formateo al mensaje
    m_texto := p_texto;
    m_texto := replace(m_texto,'"','');
    if (m_texto like '%|%' or m_texto like '%'||chr(10)||'%' or m_texto like '%<br>%') then
      m_texto := m_bullet||m_texto;
    end if;
    m_texto := replace(m_texto,'|'    ,'\n'||m_bullet);
    m_texto := replace(m_texto,chr(10),'\n'||m_bullet);
    m_texto := replace(m_texto,'<br>' ,'\n'||m_bullet);
    
    return '<script language="javascript">'
        || ' setTimeout(function(){' 
        || '   swal({text:"'||m_texto||'",icon:"'||p_icon||'"})'
        || case when p_icon='success' and g_pagina.cerrar_al_guardar='S' then '.then((value) => {window.location.href = "/Bienvenida.aspx";})' else '' end||';'
        || ' }, 50);'
        || '</script>';
  end alert;

  procedure pasar_parametros(
    p_cursor     in integer,
    p_sentencia  in varchar2,
    p_parametro  in varchar2,
    p_valor      in varchar2
  ) is
    v_key   varchar2(100);
    v_val   clob;

    procedure bind_variable(
      p_par in varchar2,
      p_val in varchar2
    ) is
    begin
      -- ver si la sentencia requiere este parametro
      if (upper(p_sentencia) like '%'||upper(':'||p_par)||'%') then
        dbms_sql.bind_variable(p_cursor,':'||p_par,p_val);
        g_valores_parametros := g_valores_parametros||chr(10)||p_par||'=['||p_val||'] used';
      end if;
    end;
  begin
    -- inicializar con null los parametros que se pasarán a la consulta dinamica
    declare
      v_param  varchar2(100);
      v_found  boolean := false;
      v_letra  varchar(1);
    begin
      -- primero: pasar null a todos los parametros para que no de error ORA-01008: not all variables bound
      for n in 1..length(p_sentencia||' ') loop
        v_letra := substr(p_sentencia,n,1);
        if (v_letra=':') then
          -- encontre un nuevo parametro
          v_found := true;
          v_param := v_letra;
        else
          if (v_found=true) then
            if (v_letra between 'A' and 'Z'
            or  v_letra between 'a' and 'z'
            or  v_letra between '0' and '9'
            or v_letra='_'
            ) then
              -- voy leyendo letras de un nuevo parametro
              v_param := v_param||v_letra;
            else
              -- termine de leer letras del parametro
              v_found := false;
              begin
                dbms_sql.bind_variable_char(p_cursor,v_param,null);
              exception when others then
                null;
              end;
            end if;
          end if;
        end if;
      end loop;
    end;

    -- solo para insertar en man_excepciones_t en caso de que dé error sepamos los valores que se pasaron y los que no
    g_valores_parametros := 'parametros {';

    -- pasar los parametros standares que requiera
    bind_variable('ID_SESION'          ,g_id_sesion);
    bind_variable('ID_PAGINA'          ,g_pagina.id_pagina);
    bind_variable('ID_USUARIO'         ,g_id_usuario_procesa);
    bind_variable('ID_INVENTARIO'      ,g_id_inventario);
    bind_variable('ID_USUARIO_PROCESA' ,g_id_usuario_procesa);
    bind_variable('ID_USUARIO_LOGUEADO',g_id_usuario_procesa);
    bind_variable('ID_MAESTRO'         ,sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO'));
    bind_variable('ID_REGISTRO'        ,sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO'));

    -- pasar los parametros del registro (debe ser antes que los del formulario)
    v_key := g_registro.FIRST;
    WHILE (v_key IS NOT NULL) LOOP
      v_val := g_registro(v_key);
      bind_variable('TXT_'||v_key,v_val);
      v_key := g_registro.NEXT(v_key);
    END LOOP;

    -- pasar los parametros del formulario (debe ser despues de los del registro)
    v_key := g_formulario.FIRST;
    WHILE (v_key IS NOT NULL) LOOP
      v_val := g_formulario(v_key);
      if (substr(v_key,1,7)<>'FILTRO_') then
        bind_variable(v_key,v_val);
      end if;
      v_key := g_formulario.NEXT(v_key);
    END LOOP;
    -- pasar los parametros de los filtros leyendo de la sesion (por si no estan el el formulario, como cuando vienes de agregar o modificar)
    for filtros in (
      select llave,valor
      from inv_db.man_sesiones_t
      where id_sesion = g_id_sesion
      and id_pagina = g_pagina.id_pagina
      and id_usuario = g_id_usuario_procesa
      and llave like 'FILTRO_%'
    ) loop
      v_key := filtros.llave;
      v_val := filtros.valor;
      -- encontrar las caracteristicas del filtro
      for i in 1..g_filtros.count loop
        if (v_key = 'FILTRO_'||g_filtros(i).secuencia) then
          if upper(g_filtros(i).condicion) = 'LIKE_U' then
            bind_variable(v_key,'%'||upper(v_val)||'%');
          elsif upper(g_filtros(i).condicion) = 'LIKE' then
            bind_variable(v_key,'%'||v_val||'%');
          elsif upper(g_filtros(i).condicion) = 'CHK' then
            bind_variable(v_key,'S');
          else
            bind_variable(v_key,v_val);
          end if;
          exit;
        end if;
      end loop;
    end loop;

    -- este debe ser el ultimo, para que sobreescriba la sesion o el formulario, si es necesario
    if (p_parametro is not null) then
      bind_variable(p_parametro,p_valor);
    end if;

    g_valores_parametros := g_valores_parametros||'}';

  end;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : ejecutar una sentencia dinamica parametrizada y retornar un unico valor
    * p_sentencia: sentencia dinamica a ejecutar
    * @returns : primera y unica columna de la primera y unica fila que devuelve la sentencia
  */
  function ejecutar(
    p_sentencia  in varchar2,
    p_parametro  in varchar2 default null,
    p_valor      in varchar2 default null
  ) return varchar2 is
    v_sentencia    varchar2(32000);
    v_resultado    varchar2(32000);

    z_theCursor        integer default dbms_sql.open_cursor;
    z_column           varchar2(32000);
    z_status           integer;
    z_descTbl          dbms_sql.desc_tab;
    z_colCnt           number;
  begin
    -- convertir el parametro en variable porque le haremos cambios
    v_sentencia := p_sentencia;

    -- convertir las etiquetas en parametros
    v_sentencia := replace(replace(v_sentencia,'[',':'),']','');

    -- parsear la sentencia
    dbms_sql.parse(z_theCursor, v_sentencia, dbms_sql.native);
    pasar_parametros(z_theCursor, v_sentencia, p_parametro, p_valor);

    -- describir las columnas
    begin
      dbms_sql.describe_columns(z_theCursor, z_colCnt, z_descTbl);
    exception when others then
      raise;
    end;
    
    for i in 1 .. z_colCnt loop
      dbms_sql.define_column(z_theCursor,i,z_column,32000);
    end loop;

    declare
      z_error varchar2(4000);
    begin
      z_status := dbms_sql.execute(z_theCursor);           -- ignore este warning
    exception when others then
      z_error := sqlerrm;
      insert into inv_db.man_excepciones_t (excepcion,agregado_por,agregado_en)
      values ('Error al ejecutar Query Dinámico:'||z_error||chr(10)||v_sentencia||chr(10)||g_valores_parametros,g_id_usuario_procesa,sysdate);
      commit;

      dbms_sql.close_cursor(z_theCursor);
    end;

    begin
      if (dbms_sql.fetch_rows(z_theCursor)=1) then         -- es un count, siempre devolvera una fila con una columna
        dbms_sql.column_value(z_theCursor,1,v_resultado);  -- cojer la columna 1 y poner el valor en m_total_registro
      end if;
    exception when others then
      raise_application_error(-20000,'v_sentencia='||v_sentencia||chr(10)||'='||sqlerrm);
    end;

    dbms_sql.close_cursor(z_theCursor);
    return v_resultado;
  end;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : obtener todos los campos del registro que se deseea ver o editar
    *            es el equivalente de quimera a los métodos paquete.getTalCosa(id) del suir en los diferentes paquetes
    * @p_solo_ver: S/N que indica si el registro se requiere solo para verlo
    *              para el campo estado_registro, por ejemplo:
    *              si p_solo_ver=S devolveriamos la descripcion del estado_registro: Activo o Inactivo
    *              si p_solo_ver=N devolveriamos el campo estado_registro: A o I para poder renderizar un radiogroup con el valor correcto seleccionado
  */
  function registro(
    p_solo_ver           in varchar2
  )
  return t_formulario
  is
    m_registro         inv_db.man_mantenimientos_pkg.t_formulario;

    m_consulta         varchar2(4000);
    l_theCursor        integer default dbms_sql.open_cursor;
    l_colCnt           number;
    l_descTbl          dbms_sql.desc_tab;
    l_columnName       varchar2(2000);

    l_columnAll        varchar2(32000);
    l_columnClob       clob;
    l_columnValue      clob;

    l_status           integer;
    m_solo_ver         varchar2(100) := p_solo_ver;
  begin
    -- antes de sacar los campos para popular el REGISTRO seleccionado
    -- se debe determinar si el registro será SOLO-LECTURA o no
    -- porque en caso de ser solo lectura se usa EXPRESION, sinó COLUMNA
    if (m_solo_ver='N' and g_pagina.condicion_solo_lectura is not null) then
      -- los elementos dinámicos g_pagina.condicion_solo_lectura, g_pagina.consultar y g_pagina.campo_id vienen de inv_db.man_paginas_t y no son input del usuario
      m_consulta := 'select '||g_pagina.condicion_solo_lectura||' as condicion'
                 || ' from ('||g_pagina.consultar||') a'
                 || ' where a.'||g_pagina.campo_id||'=:ID_REGISTRO';

      m_solo_ver := ejecutar(m_consulta);
    end if;

    m_consulta := 'select '||g_pagina.campo_id;
    for i in 1..g_columnas.count loop
      if ( g_columnas(i).tipo_de_dato <> 'DOWN') then -- las columnas DOWN sacan su blob con un query aparte de este    
       if (substr(lower(g_columnas(i).columna),1,2)<>'p_' or g_columnas(i).expresion is not null) then
        if upper(g_columnas(i).tipo_de_dato) not in('MCHK') then
           if (m_solo_ver='S' or g_columnas(i).tipo_de_dato in('LBL','HTML','CODE','UL','OL')) then
             --usar EXPRESION
             m_consulta := m_consulta||','||case when g_columnas(i).expresion is not null then g_columnas(i).expresion||' as '||g_columnas(i).columna else g_columnas(i).columna end;
           else
             -- usar COLUMNA
             m_consulta := m_consulta||','||g_columnas(i).columna;
          end if;
         end if;
       end if;
     end if;
    end loop;

    m_consulta := m_consulta||' from ('||g_pagina.consultar||') a where a.'||g_pagina.campo_id||'= :ID_REGISTRO ';
    m_consulta := replace(replace(m_consulta,'[',':'),']','');
    
    dbms_sql.parse( l_theCursor, m_consulta, dbms_sql.native );
    pasar_parametros(l_theCursor,m_consulta,null,null);
    dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
    for i in 1 .. l_colCnt loop
      begin
         dbms_sql.define_column(l_theCursor, i, l_columnAll, 32000);
      exception when others then
        dbms_sql.define_column_long(l_theCursor,i);
      end;
    end loop;
    l_status := dbms_sql.execute(l_theCursor); --ignore
    -- iterar las columnas del unico registro que devuelve
    while(dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
      for i in 1 .. l_colCnt loop -- empezamos en las 2 porque la columna  1 se puso manual
        l_columnName := l_descTbl(i).col_name;
        begin
          dbms_sql.column_value( l_theCursor, i, l_columnAll);
          l_columnValue := l_columnAll;
        exception when others then
          dbms_sql.column_value( l_theCursor, i, l_columnClob);
          l_columnValue := l_columnClob;
        end;
        -- agregar el campo y su valor a la coleccion registro
        m_registro(l_columnName) := l_columnValue;
      end loop;
    end loop;
    dbms_sql.close_cursor(l_theCursor);

    return m_registro;
  end registro;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar el control html que dibuija un boton
    * @p_icono: Palabra clave que representa el ícono gráfico a mostrar, ver https://fonts.google.com/icons?icon.style=Rounded
    * @p_nombre: Nombre del input-control
    * @p_tipo: tipo de boton, submit o reset
    * @p_titulo: Título o texto del botón
    * @p_valor: valor que envia al ser presionado
    * @p_desabilitado: S/N que indica si el boton debe renderizarse desabilitado.
    * @p_estilo: CSS tags para formatear el input-control
    * @p_confirmacion: texto de confirmación que se muestra al presionarse el botón
    * @return el html que renderiza un botón
  */
  function boton(
    p_icono         in varchar2,
    p_nombre        in varchar2,
    p_tipo          in varchar2,
    p_titulo        in varchar2,
    p_valor         in varchar2,
    p_desabilitado  in varchar2 default null,
    p_estilo        in varchar2 default null,
    p_confirmacion  in varchar2 default null
  )
  return varchar is
  BEGIN
    return '<button'
        || ' type="'||p_tipo||'"'
        || ' name="'||p_nombre||'"'
        || ' value="'||p_valor||'"'
        || case when p_estilo is not null then ' style="'||p_estilo||'"' else '' end
        || case when p_desabilitado='S'   then ' disabled ' else '' end
        || ' '||p_confirmacion
        || case when p_nombre like 'BTN_TAB_%' then ' formnovalidate ' else '' end
        || '>'
        || case when p_icono is not null then '<img src="/_images/'||p_icono||'.png" />' else '' end
        || '<span class="btn_label">'||p_titulo||'</span>'
        || '</button>';
  end boton;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar un control html basandose en las caracteristicas definidas en la coleccion de columnas de una pagina
    * @P_nombre: Nombre del input-control
    * @p_tipo: Control que se renderiza en caso de editar/agregar:
    *   LBL=Label, TXT=Textbox, HTML=Visor de html, ICON=Icono visual, PASS=Password, NUM=Num. entero, DEC=Num. decimal, FEC=Fecha, HORA=Hora,
    *   RAD=Radiobutton, CHK=Checkbox, LOV=Select, DAL=Datalist, MEMO=Textarea, MCHK=Multi-checkboxes, MULTI=Multi-select, IMG=Imagen, DOC=Documento,
    *   OL=Lista numerada, UL=Lista buleteada., HTML, CODE, DOWN=Descargados de archivos
    * @p_requerido: S/N que indica si es obligatorio especificar un valor para este control antes de poder hacer post-back
    * @p_placeholder: especifica un placeholder para este control, si aplica
    * @p_valor: valor del input control
    * @p_min: Valor mínimo permitido para este input-control: puede ser una constante o una sentencia Sql
    * @p_max: Valor máximo permitido para este input-control: puede ser una constante, la palabra MAX o una sentencia Sql
    * @p_longitud: Longitud máxima en bytes para el input control
    * @p_regexp_val: Regular expression que límita los valores que acepta el input-control
    * @p_regexp_msg: Mensaje a mostrar al usuario cuando no se cumplen los requisitos del regular expression
    * @p_estilo: CSS tags para formatear el input-control
    * @p_autopostback: S/N que indica si el control hace post-back cada vez que el usuario logueado cambie su valor
    * @p_lista_de_valores: Lista de valores para el input-control, puede ser una lista fija separada por comas A=Activo,I=Inactivo o una sentencia Sql
    * @returns un clob con la representración html del control deseado
  */
  function input_control(
    P_nombre        in varchar2,
    p_tipo          in varchar2,
    p_requerido     in varchar2 default 'N',
    p_placeholder   in varchar2 default null,
    p_valor         in clob default null,
    p_longitud      in number default null,
    p_regexp_val    in varchar2 default null,
    p_regexp_msg    in varchar2 default null,
    p_estilo        in varchar2 default null,
    p_autopostback  in varchar2 default 'N',
    p_lista_de_valores in varchar2 default null
  )
  return clob is
    v_resultado        clob;
    m_valor            clob;
    m_blob             blob;
    m_res              varchar2(4000);
  begin
    -- cambiar " por &quot; para que los edits no cierren antes e la cuenta
    m_valor := replace(p_valor,'"','&quot;');
    
    -- corregir  cuando oracle devuelve -.12 en vez de -0.12
    if (p_tipo in('NUM','DEC','FLOAT') and m_valor like '-.%') then
      m_valor := replace(m_valor,'-.','-0.');
    end if;

    if p_tipo not in ('LBL','TXT','ICON','PASS','NUM','DEC','FEC','HORA','CHK','MEMO','IMG','DOC','FLOAT','HTML','CODE','DOWN','FIRMA') THEN
      v_resultado := 'Error: tipo de control no encontrado:'||p_tipo;
    elsif p_tipo = 'FIRMA' then
      --if (m_valor is not null and length(m_valor)>0) then
      --  v_resultado := '<img src="'||m_valor||'">';
      --else
        v_resultado := '<input type="hidden" name="'||p_nombre||'" id="'||p_nombre||'">'||chr(13)
                    || '<canvas id="sig-canvas" class="firma_frame" width="275" height="150"></canvas>'||chr(13)
                    || '<div id="firma_botones">'||chr(13)
                    || ' <span id="sig-submitBtn" class="firma_botones">Aceptar</span>'||chr(13)
                    || ' <span id="sig-clearBtn"  class="firma_botones">Borrar</span>'||chr(13)
                    || '</div>'||chr(13)
                    ||'
<script>
(function() {
  window.requestAnimFrame = (function(callback) {
    return window.requestAnimationFrame ||
      window.webkitRequestAnimationFrame ||
      window.mozRequestAnimationFrame ||
      window.oRequestAnimationFrame ||
      window.msRequestAnimationFrame ||
      function(callback) {
        window.setTimeout(callback, 1000 / 60);
      };
  })();

  var canvas = document.getElementById("sig-canvas");
  var ctx = canvas.getContext("2d");
  ctx.strokeStyle = "#222222";
  ctx.lineWidth = 2;
  ctx.fillStyle = "white";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

'||
case 
when m_valor is not null then '
  var img = new window.Image();
  img.addEventListener("load", function () {
    ctx.drawImage(img, 0, 0);
  });
  img.setAttribute("src", "'||m_valor||'");
' else '' end  
||'

  var drawing = false;
  var mousePos = {
    x: 0,
    y: 0
  };
  var lastPos = mousePos;
  canvas.addEventListener("mousedown", function(e) {
    drawing = true;
    lastPos = getMousePos(canvas, e);
  }, false);

  canvas.addEventListener("mouseup", function(e) {
    drawing = false;
  }, false);

  canvas.addEventListener("mousemove", function(e) {
    mousePos = getMousePos(canvas, e);
  }, false);

  // Add touch event support for mobile
  canvas.addEventListener("touchstart", function(e) {

  }, false);

  canvas.addEventListener("touchmove", function(e) {
    var touch = e.touches[0];
    var me = new MouseEvent("mousemove", {
      clientX: touch.clientX,
      clientY: touch.clientY
    });
    canvas.dispatchEvent(me);
  }, false);

  canvas.addEventListener("touchstart", function(e) {
    mousePos = getTouchPos(canvas, e);
    var touch = e.touches[0];
    var me = new MouseEvent("mousedown", {
      clientX: touch.clientX,
      clientY: touch.clientY
    });
    canvas.dispatchEvent(me);
  }, false);

  canvas.addEventListener("touchend", function(e) {
    var me = new MouseEvent("mouseup", {});
    canvas.dispatchEvent(me);
  }, false);

  function getMousePos(canvasDom, mouseEvent) {
    var rect = canvasDom.getBoundingClientRect();
    return {
      x: mouseEvent.clientX - rect.left,
      y: mouseEvent.clientY - rect.top
    }
  }

  function getTouchPos(canvasDom, touchEvent) {
    var rect = canvasDom.getBoundingClientRect();
    return {
      x: touchEvent.touches[0].clientX - rect.left,
      y: touchEvent.touches[0].clientY - rect.top
    }
  }

  function renderCanvas() {
    if (drawing) {
      ctx.moveTo(lastPos.x, lastPos.y);
      ctx.lineTo(mousePos.x, mousePos.y);
      ctx.stroke();
      lastPos = mousePos;
    }
  }

  // Prevent scrolling when touching the canvas
  document.body.addEventListener("touchstart", function(e) {
    if (e.target == canvas) {
      e.preventDefault();
    }
  }, false);
  document.body.addEventListener("touchend", function(e) {
    if (e.target == canvas) {
      e.preventDefault();
    }
  }, false);
  document.body.addEventListener("touchmove", function(e) {
    if (e.target == canvas) {
      e.preventDefault();
    }
  }, false);

  (function drawLoop() {
    requestAnimFrame(drawLoop);
    renderCanvas();
  })();

  function clearCanvas() {
    canvas.width = canvas.width;
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    document.getElementById("'||p_nombre||'").value = '''';
  }
  
  // Set up the UI
  var sigText = document.getElementById("sig-dataUrl");
  var sigImage = document.getElementById("sig-image");
  var clearBtn = document.getElementById("sig-clearBtn");
  var submitBtn = document.getElementById("sig-submitBtn");
  var input = document.getElementById("'||p_nombre||'");

  clearBtn.addEventListener("click", function(e) {
    clearCanvas();
    sigImage.setAttribute("src", "");
  }, false);

  submitBtn.addEventListener("click", function(e) {
    var dataUrl = canvas.toDataURL("image/jpeg", 1.0);
    input.value = dataUrl;
    document.getElementById("firma_botones").style.display="none";
    canvas.style.backgroundColor="white";
    canvas.style.borderColor="white";
    canvas.style.pointerEvents = "none";
  }, false);
})();
</script>'||chr(13);
      --end if;
    elsif p_tipo = 'MEMO' then
       v_resultado := '<textarea id="'||P_nombre||'" name="'||P_nombre||'" '
                   || case when p_estilo is not null then 'style="'||p_estilo||'" ' else 'rows="3" cols="50" ' end
                   || case when p_longitud is not null then 'maxlength="'||p_longitud||'" ' else '' end
                   || case when upper(p_requerido) = 'S' then ' required ' end
                   || '>'
                   || case when m_valor is not null then m_valor end
                   || '</textarea>';
    elsif p_tipo = 'LBL' then
      -- si el label viene con lista de valores que es un select, ejecutarlo y tomar eso como valor
      if (lower(trim(p_lista_de_valores)) like 'select %' or lower(trim(p_lista_de_valores)) like 'with %') then
        m_valor := ejecutar(p_lista_de_valores);
      end if;
      v_resultado := '<span id="'||P_nombre||'" style="white-space: pre-line; '||p_estilo||'">'
                  || HTF.ESCAPE_SC(m_valor)
                  || '</span>';
    elsif p_tipo = 'ICON' then
       v_resultado := '<img id="'||P_nombre||'" src="/_images/'||m_valor||'.png" />';
    elsif p_tipo = 'HTML' then
      if (lower(trim(p_lista_de_valores)) like 'select %' or lower(trim(p_lista_de_valores)) like 'with %') then
        m_valor := ejecutar(p_lista_de_valores);
      end if;
      v_resultado := '<div id="'||P_nombre||'" style="padding-top:6px;'||p_estilo||'">'|| m_valor||'</div>';
    elsif p_tipo = 'CODE' then
      v_resultado := '<pre id="'||P_nombre||'" style="'||p_estilo||'">'||m_valor||'</pre>';
    elsif p_tipo = 'DOWN' then
      -- no renderizar el boton de descargar si no hay nada cargado
      declare
        m_sql  varchar2(1000);
        m_cnt  int;
        m_col  varchar2(100)  := replace(p_nombre,'TXT_','');
        m_id   varchar2(1000) := g_registro(upper(g_pagina.campo_id));
        m_file varchar2(100);
      begin
        if (g_registro.exists(upper(g_pagina.campo_id)) and g_registro(upper(g_pagina.campo_id)) is not null) then
          m_sql := 'select count(*) from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:id and x.'||m_col||' is not null';
          if (lower(m_sql) like '%:id_inventario%') then
            execute immediate m_sql into m_cnt using g_id_inventario, m_id;
          else
            execute immediate m_sql into m_cnt using m_id;
          end if;
          if (m_cnt<>0) then
            m_sql := 'select '||m_col||'_filename from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:id';
            --execute immediate m_sql into m_file using m_id;
            if (lower(m_sql) like '%:id_inventario%') then
              execute immediate m_sql into m_file using g_id_inventario, m_id;
            else
              execute immediate m_sql into m_file using m_id;
            end if;
            v_resultado :=  boton(
                              p_icono         => null,
                              p_nombre        => 'BTN_DOWNLOAD',
                              p_tipo          => 'submit',
                              p_titulo        => 'Descargar',
                              p_valor         => encrypt(
                                                  'id='||m_id                             -- el id del registro actual
                                                 ||',field='||replace(p_nombre,'TXT_','') -- el campo a descargar
                                                 ||',filename='||m_file                   -- el campo que se usará como nombre del archivo
                                                 ||',ext='||p_lista_de_valores            -- la extensión del archivo
                                                 ||',type='||p_valor                      -- el content type del archivo
                                                 ),
                              p_desabilitado  => 'N',
                              p_estilo        => null,
                              p_confirmacion  => null
                            );
          end if;
        end if;
      end;
    else
       v_resultado := '<input name="'||p_nombre||'" '
                   || case when upper(p_requerido) = 'S' then ' required ' end
                   || case when p_estilo is not null then ' style="'||p_estilo||'"' end
                   || case when p_longitud is not null then 'maxlength="'||
                                                             case
                                                               when p_tipo='NUM'   then p_longitud+1    -- el posible guión
                                                               when p_tipo='DEC'   then p_longitud+2    -- el posible guión y un punto
                                                               when p_tipo='FLOAT' then p_longitud+2    -- el posible guión y un punto
                                                               when p_tipo='FEC'   then 10              -- ancho standard de una fecha dd/mm/yyyy
                                                               when p_tipo='HORA'  then 10              -- ancho standard de una hora hh:mi AM
                                                               else p_longitud
                                                             end
                                                           ||'" ' else '' end
                   || case p_tipo
                      when 'TXT'   then 'type="text" '
                      when 'PASS'  then 'type="password" autocomplete="new-password" '

                      when 'NUM'   then 'type="text" pattern="^-?([0-9]{1,3},([0-9]{3},)*[0-9]{3}|[0-9]+)+$"               title="Debe ser un número entero válido."'
                      when 'DEC'   then 'type="text" pattern="^-?([0-9]{1,3},([0-9]{3},)*[0-9]{3}|[0-9]+)+(.[0-9]{1,2})?$" title="Debe ser un número válido con 2 decimales máximo."'
                      when 'FLOAT' then 'type="text" pattern="^-?([0-9]{1,3},([0-9]{3},)*[0-9]{3}|[0-9]+)+(.[0-9]{1,6})?$" title="Debe ser un número válido con 6 decimales máximo."'
                      when 'FEC'   then 'type="text" class="fecha" autocomplete="off" '||case when nvl(p_autopostback,'N')='S' then ' onchange="this.form.submit()"' else '' end
                      when 'HORA'  then 'type="time" class="hora" style="width:6.6em;" autocomplete="off" '||case when nvl(p_autopostback,'N')='S' then ' onchange="this.form.submit()"' else '' end
                      when 'CHK'   then 'type="checkbox" '
                      when 'IMG'   then 'type="file" accept="image/jpeg" onchange="upload_check(this)" '
                      when 'DOC'   then 'type="file"'||case when p_placeholder is not null then ' accept="'||p_placeholder||'"' else '' end||' onchange="upload_check(this)" '
                      end
                   || case when p_placeholder is not null then ' placeholder="' ||p_placeholder||'"' else '' end
                   || case
                      when m_valor is not null and p_tipo = 'FEC'   then ' value="' ||man_formatear_pkg.y_m_d(m_valor)||'"'
                      when m_valor is not null and p_tipo = 'DEC'   then ' value="' ||trim(REGEXP_REPLACE(m_valor, '[^0-9.-]+', ''))||'"'
                      when m_valor is not null and p_tipo = 'FLOAT' then ' value="' ||trim(REGEXP_REPLACE(m_valor, '[^0-9.-]+', ''))||'"'
                      when m_valor = 'S'       and p_tipo = 'CHK'   then ' checked '
                      when m_valor is not null and p_tipo in ('TXT','PASS','NUM','HORA') then ' value="'||m_valor||'"'
                      else ''
                      end
                   || case when p_longitud is not null then ' maxlength="' ||p_longitud||'"' else '' end
                   || case when p_regexp_val is not null and p_tipo not in ('NUM','DEC','FLOAT') then ' pattern="' ||p_regexp_val||'"' else '' end
                   || case when p_regexp_msg is not null and p_tipo not in ('NUM','DEC','FLOAT') then ' title="' ||p_regexp_msg||'"' else '' end
                   --|| case when upper(p_requerido) = 'S' and p_tipo in ('TXT','PASS','NUM','DEC','FEC','HORA','MEMO','IMG','DOC','FLOAT') then ' required ' else '' end
                   || '>';

                   if (p_tipo in('TXT','NUM','DEC','FLOAT') and nvl(p_autopostback,'N')='S') then
                     v_resultado := v_resultado
                                 || '&nbsp;<button type="submit" name="BTN_BUSCAR" formnovalidate '||case when p_requerido='S' and m_valor is null then 'disabled' else '' end||'>Buscar</button>'; 
                     if (p_requerido='S') then
                       -- este javascript hace que al cambiar el campo que tiene autopostback se inhabilite el boton de guardar
                       -- que se enciende cuando se presione buscar (o sea: si cambias el txt tienes que buscar)
                       v_resultado := v_resultado
                                 || '<script>'
                                 || '  jQuery.noConflict();'
                                 || '  jQuery(document).ready(function($){'
                                 || '    $("[name='''||p_nombre||''']").on(''input'',function(){'
                                 || '     document.getElementsByName("BTN_INSERTAR").forEach((e) => {e.disabled = true;});'
                                 || '     document.getElementsByName("BTN_MODIFICAR").forEach((e) => {e.disabled = true;});'
                                 || '     if (!$("[name='''||p_nombre||''']").val()){ '
                                 || '       $("[name=''BTN_BUSCAR'']").prop(''disabled'', true);'
                                 || '     } else {'
                                 || '       $("[name=''BTN_BUSCAR'']").prop(''disabled'', false); '
                                 || '     } '
                                 || '    });'
                                 || '  });'
                                 || '</script>';
                     end if;
                   end if;
    end if;
    
    -- manejo para renderizar una imagen
    if (p_tipo='IMG') then
      
      v_resultado := v_resultado||'&nbsp;<input type="checkbox" id="'||p_nombre||'_REMOVER" name="'||p_nombre||'_REMOVER">&nbsp;Remover';
      -- ver si está en sesion (recien cargada)
      begin
        select documento
        into m_blob
        from inv_db.man_sesiones_t s
        where s.id_sesion = g_id_sesion
        and s.id_usuario = g_id_usuario_procesa
        and s.id_pagina = g_pagina.id_pagina
        and s.llave = p_nombre
        and s.documento is not null;
      exception when no_data_found then
        -- ver si está en el registro de esta tabla (cargada desde antes)
        declare
          m_sql varchar2(32000);
        begin
          m_sql := 'select '||replace(p_nombre,'TXT_','')||' from ('||g_pagina.consultar||') where '||g_pagina.campo_id||'=:id';
          --execute immediate  m_sql into m_blob  using sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
          if (lower(m_sql) like '%:id_inventario%') then
            execute immediate  m_sql into m_blob  using g_id_inventario,sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
          else
            execute immediate  m_sql into m_blob  using sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
          end if;
        exception when no_data_found then
          m_blob := null;
        end;
      end;

      v_resultado := v_resultado
                  ||'<img id="'||p_nombre||'_JPG" style="width:98%; max-width:500px; display:block;"'
                  ||' src="'||case when m_blob is null then '' else 'data:image/jpeg;base64,'||inv_db.man_formatear_pkg.base64encode(m_blob) end||'"'
                  ||' alt="">
<script>
 jQuery(document).ready(function($){
  var foto = document.getElementById("'||p_nombre||'_JPG");
  var input = document.getElementsByName("'||p_nombre||'")[0];
  input.onchange=function() {
    document.getElementById("'||p_nombre||'_REMOVER").checked = false;
    var file = input.files[0];
    if (file) {
      var filereader = new FileReader();
      filereader.readAsDataURL(file);
      filereader.onload = function (evt) {
         var base64 = evt.target.result;
         foto.src = base64;
         foto.show();
      }
    }
  }

  if ($("#'||p_nombre||'_REMOVER").prop("checked")) {
    $("#'||p_nombre||'_JPG").hide();
  } else {
    $("#'||p_nombre||'_JPG").show();
  }  

  $("#'||p_nombre||'_REMOVER").click(function(){
    if ($("#'||p_nombre||'_REMOVER").prop("checked")) {
      $("#'||p_nombre||'_JPG").hide();
    } else {
      $("#'||p_nombre||'_JPG").show();
    }  
  });  
 }); 
</script>  
';

    end if;

    -- manejo de los textbox con boton de buscar
    if (p_tipo='TXT' and p_autopostback='S' and p_lista_de_valores is not null) then
     if (m_valor is not null) then
      begin
        m_res := ejecutar(p_lista_de_valores);
        if (m_res like 'ER|%') then
          -- ver si estamos aqui porque se presionó el boton de insertar o modificar
          if (g_formulario.exists('BTN_BUSCAR') or g_formulario.exists('BTN_INSERTAR') or g_formulario.exists('BTN_MODIFICAR')) then
            v_resultado := v_resultado||alert(substr(m_res,4),'error'); -- mostrará el dialogo de error
          end if;
          v_resultado := v_resultado||'<span id="DESC_'||p_nombre||'"></span>'; --esto no se ve
        else
          v_resultado := v_resultado||'<div id="DESC_'||p_nombre||'">'||m_res||'</div>';
        end if;
      exception when no_data_found then
        v_resultado := v_resultado||alert('El valor especificado no fue encontrado.','error');
        v_resultado := v_resultado||'<span id="DESC_'||p_nombre||'"></span>'; --esto no se ve
      end;
     end if;
    end if;

    -- si se desea que no renderise un control en especifico, marcar un caracter backspace - chr(8) en el valor
    if (m_valor=chr(8) and p_tipo<>'IMG') then
      v_resultado := '';
    end if;

    return v_resultado;
  END input_control;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar una lista de valores
    * @p_nombre: Nombre del input-control
    * @p_lista_valores: Lista de valores para el input-control, puede ser una lista fija separada por comas A=Activo,I=Inactivo o una sentencia Sql
    * @p_requerido: S/N que indica si es obligatorio especificar un valor para este control antes de poder hacer post-back
    * @p_seleccionado: Valor que debe mostrarse seleccionado en la lista de valores o radiogroup actual
    * @p_deshabilitado: S/N que representa si la lista debe mostrarse desabilitada o no
    * @p_tipo_dato: Código que indica el input control a renderizar, por ejemplo:
    *               LOV un select control con busqueda incremental (el que mas se usa)
    *               RAD radiogroup
    *               MULTI un select-control que permite seleccionar varios
    *               MCHK renderiza multiples checkboxes, uno por cada registro de la lista de valires
    *               DAL  renderiza un datalis, un select que permite escribir el texto si no está en la lista
    *               UL y OL bullets o viñetas numéricas
    * @p_autoposback: S/N que indica si el control hace post-back cada vez que el usuario logueado cambie su valor
    *               esto se usa principalmente para los select en cascada, si elijes una provincia hace postback y puedes usar [LOV_PROVINCIA]
    *               en el select de los municipios
    * @p_estilo: CSS tags para formatear el input-control
    * @p_valor_parametro: Valor de input del usuario requerido por la consulta dinamica de p_lista_de_valores
    * @returns un clob con la renderización html del control lista de valores deseado
  */
  FUNCTION lista_de_valores(
    p_nombre           in varchar2,
    p_lista_valores    in varchar2,
    p_requerido        in varchar2, --S no acepta nulo y seleccione esta en la lista, N acepta nulo y seleccione esta en la lista y null
    p_seleccionado     in varchar2 default null,
    p_deshabilitado    in varchar2 default 'N',
    p_tipo_dato        in varchar2 default 'RAD',
    p_autoposback      in varchar2 default 'N',
    p_estilo           in varchar2 default null
  ) return clob is
    --Val l_listas
    m_id              varchar2(1000);
    m_des             varchar2(1000);
    --Val l_lista_opc
    m_id_reg          varchar2(1000);
    m_id_det          varchar2(1000);
    m_desc            varchar2(1000);
    m_secuencia       varchar2(1000);
    m_selecionado     varchar2(1000);
    v_sql             varchar2(15000);
    v_resultado       clob;
    v_nom_control     varchar2(1000);
  BEGIN
    v_nom_control := 'id="'||p_nombre||'" name="'||p_nombre||'"';
    if (p_estilo is not null and p_tipo_dato not in('RAD')) then
      v_nom_control := v_nom_control||' style="'||p_estilo||'"';
    end if;

    IF p_tipo_dato in('LOV') THEN
      v_resultado := v_resultado||'<select '|| v_nom_control||' single="single" '
                  --|| case when p_requerido='S' then ' required' else '' end
                  || case when p_deshabilitado='S' then ' disabled' else '' end
                  || case when p_autoposback  ='S' then ' onchange="this.form.submit()"' else '' end
                  || '>';
      if (p_requerido='N') then
        v_resultado := v_resultado||'<option value="" '
                    || case when p_seleccionado=m_id then 'selected' else '' end
                    || ' selected >Seleccione un valor</option>';
      elsif(p_requerido='S' and p_seleccionado is null) then
        v_resultado := v_resultado||'<option value="" '
                    || case when p_seleccionado=m_id then 'selected' else '' end
                    || ' disabled selected >Seleccione un valor</option>';
      end if;
    ELSIF (p_tipo_dato = 'RAD') THEN
      v_resultado := v_resultado||'<div style="'||p_estilo||'">';
    ELSIF (p_tipo_dato = 'MULTI') THEN
          v_resultado := v_resultado||'<select style="width:100%;" '||v_nom_control||' multiple="multiple" '
                      --|| case when p_requerido='S' then ' required' else '' end
                      || '>';
    ELSIF p_tipo_dato = 'DAL' THEN
             v_resultado := v_resultado||'<input type="text" list="'||p_nombre||'s" name="'||p_nombre||'"'||case when p_estilo is not null then ' style="'||p_estilo||'"' else '' end||
                             case when p_deshabilitado='S' then ' disabled ' else '' end||'>';
             v_resultado := v_resultado||'<datalist id="'||p_nombre||'s" '||' name="'||p_nombre||'" '||
                      case when p_deshabilitado='S' then ' disabled' else '' end ||
                      case when p_autoposback='S' then ' onchange="this.form.submit()"' else '' end ||
                          '>';
    ELSIF p_tipo_dato = 'OL' THEN
              v_resultado := v_resultado||'<ol>';

    ELSIF p_tipo_dato = 'UL' THEN
              v_resultado := v_resultado||'<ul>';
    END IF;

    v_sql := trim(p_lista_valores);
    
    if (lower(v_sql) not like 'select %' and substr(lower(v_sql),-2) != '_v' and p_tipo_dato != 'MCHK') then
      -- esta consulta dinamica convierte en cursor una lista fija en formato A=Activo,I=Inactivo,
      -- viene de inv_db.man_det_columnas_paginas_t y no es input del usuario
      v_sql := 'SELECT SUBSTR(CAMPO,1,instr(CAMPO,''='')-1)ID, SUBSTR(CAMPO,instr(CAMPO,''='')+1,instr(CAMPO,''='')+50) DES '
            || 'FROM ('
            || 'SELECT REGEXP_SUBSTR ('''||v_sql||''', ''[^,]+'', 1,LEVEL)CAMPO '
            || 'FROM DUAL '
            || 'CONNECT BY REGEXP_SUBSTR ('''||v_sql||''', ''[^,]+'', 1,LEVEL) IS NOT NULL) ';
    end if;

    DECLARE
      m_theCursor        integer default dbms_sql.open_cursor;
      m_colCnt           number;
      m_descTbl          dbms_sql.desc_tab;
      m_column           varchar2(32000);
      m_status           integer;
      m_resultado        clob;
    BEGIN
      -- esta consulta dinamica viene de man_det_filtros_paginas_t
      dbms_sql.parse(m_theCursor, v_sql, dbms_sql.native);
      pasar_parametros(m_theCursor,v_sql,null,null);
      dbms_sql.describe_columns(m_theCursor, m_colCnt, m_descTbl);
      --
      for j in 1 .. m_colCnt loop
          dbms_sql.define_column(m_theCursor,j,m_column,4000);
      end loop;
      m_status := dbms_sql.execute(m_theCursor); --ignore

      m_resultado := null;
      if (p_tipo_dato = 'MCHK') then
        while(dbms_sql.fetch_rows(m_theCursor) > 0 ) loop
          -- esta consulta requiere los siguientes campos id_registro, id_detalle, descripcion, secuencia, seleccionado
          dbms_sql.column_value( m_theCursor,1,m_id_reg);
          dbms_sql.column_value( m_theCursor,2,m_id_det); m_id_det := encrypt(m_id_det);
          dbms_sql.column_value( m_theCursor,3,m_desc);
          dbms_sql.column_value( m_theCursor,4,m_secuencia);
          dbms_sql.column_value( m_theCursor,5,m_selecionado);
          v_nom_control := 'name="'||p_nombre||'_'||m_id_det||'"';

          if p_deshabilitado = 'S' then
            m_resultado := m_resultado||case when m_selecionado = 'S' then ' &#x2611 ' else ' &#x2610 ' end||m_desc||'</label><br/></span>';
          else
            m_resultado := m_resultado||'<span><input '||v_nom_control||' type="checkbox"'||case when m_selecionado = 'S' then ' checked ' else '' end||'> '||m_desc||'</label><br/></span>';
          end if;
        end loop;
        if (m_resultado is null) then
          m_resultado := '<span>No se ha creado ningún registro.</span>';
        end if;
      else
        while(dbms_sql.fetch_rows(m_theCursor) > 0 ) loop
          -- esta consulta requiere los siguientes campos id, descripcion
          dbms_sql.column_value(m_theCursor,1,m_id);
          dbms_sql.column_value(m_theCursor,2,m_des);

          -- Si es drop down list o datalist
          IF p_tipo_dato IN ('LOV') THEN
            m_resultado := m_resultado||'<option value="'||m_id||'" '
                          || case when p_seleccionado in (m_id,m_des) then ' selected ' else '' end||'>'
                          || m_des||'</option>';
          elsif p_tipo_dato IN ('DAL') THEN
            m_resultado := m_resultado||'<option>'||m_des||'</option>';
          elsif p_tipo_dato IN ('MULTI') THEN
            m_resultado := m_resultado||'<option value="'||m_id||'" '
                        || case when ','||p_seleccionado||',' like '%,'||m_id||',%' then 'selected' else '' end||'>'
                        || m_des ||'</option>';
          ELSIF p_tipo_dato = 'RAD' THEN
            m_resultado := m_resultado||'<input type="radio" '||replace(v_nom_control,'id="'||p_nombre||'"','id="'||p_nombre||'_'||m_id||'"')||' value="'||m_id||'"'
                          || case when p_deshabilitado='S' then ' disabled ' else '' end
                          || case when p_seleccionado in (m_id,m_des) then ' checked ' else '' end||'>&nbsp;'||m_des;

          -- Si es lista enumerada o con viñetas
          ELSIF p_tipo_dato IN ('OL','UL') THEN
            m_resultado := m_resultado||'<li>'||m_des||'</li>';
          END IF;
        end loop;
        IF p_tipo_dato in ('LOV','MULTI') THEN
          m_resultado := m_resultado||'</select>';
        ELSiF p_tipo_dato = 'RAD' THEN
          m_resultado := m_resultado||'</div>';
        ELSiF p_tipo_dato = 'DAL' THEN
          m_resultado := m_resultado||'</datalist>';
        ELSiF p_tipo_dato = 'OL' THEN
          m_resultado := m_resultado||'</ol>';
        ELSIF p_tipo_dato = 'UL' THEN
          m_resultado := m_resultado||'</ul>';
        END IF;
      end if;

      v_resultado := v_resultado||m_resultado;
      dbms_sql.close_cursor(m_theCursor);
    end;

    return v_resultado;
  EXCEPTION WHEN OTHERS THEN
    return v_sql||':'||SQLERRM||chr(10)||dbms_utility.format_error_backtrace;
  END lista_de_valores;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : prepara la renderización html los tabs de detalles de una página a los que el usuario logueado tiene acceso
    * @p_column_count: cantidad de columnas de la página a mostrar, necesario para renderizar los tabs a todo lo ancho mantenimiento el responsive
    * @returns un clob conteniendo la renderización html de un tab por cada detalle de la pagina actual al que el usuario tiene acceso
  */
  function tabs(
    p_column_count   in number
  )
  return clob is
    v_resultado        clob;
    v_encrypted         varchar2(100);
  begin
    v_resultado:= v_resultado||'<tr>';
    v_resultado:= v_resultado||' <td colspan="'||p_column_count||'">';
    v_resultado:= v_resultado||'  <table class="TABS">';
    v_resultado:= v_resultado||'   <tr class="TABS_ROW">';
    for i in 1..g_tabs.count loop
      v_resultado := v_resultado||'    <td width="5" class="TAB_NOTAB"><div></div></td>';
      v_resultado := v_resultado||'    <td width="1" class="'||case when g_tabs(i).plural = g_pagina.plural then 'TAB_SEL' else 'TAB_NOSEL' end||'">';
      v_encrypted := encrypt(g_tabs(i).id_pagina);
      v_resultado := v_resultado||     boton('','BTN_TAB_'||v_encrypted,'submit',g_tabs(i).plural,null,'N',null);
      v_resultado := v_resultado||    '</td>';
    end loop;
    v_resultado := v_resultado||'    <td width="*" class="TAB_NOTAB"><div>&nbsp;</div></td>';
    v_resultado := v_resultado||'   </tr>';
    v_resultado := v_resultado||'  </table>';
    v_resultado := v_resultado||' </td>';
    v_resultado := v_resultado||'</tr>';

    return v_resultado;
  end tabs;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar la página que se muestra cuando un usuario hace click en un registro para verlo en detalle
    *            tambien se utiliza cuando se hace click para modificar y no se tiene permiso de modificarlo
  */
  procedure ver is
     --Declaración de variales
     v_label            varchar2(500);
     v_name             varchar2(2000);
     v_control          clob;
     v_grupo            varchar2(500);
     m_grupo            varchar2(500);
     v_min_seg          number;
     v_sql              varchar2(2500);
     v_valor            clob;
     m_blob             blob;
  begin
    --log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Consultar');
    g_registro       := registro('S');

    ADD('<table id="ventana" class="editar">');
    ADD('<thead>');
    ADD('<tr>');
    add('<td width="*" colspan="2" id="consultar_titulo">Ver '||g_pagina.singular||'</td>');
    --if g_tabs.count > 0 then
      ADD('<td width="1" align="right">'||replace(boton(p_icono => 'arrow_back_ios_new',p_nombre => 'BTN_VOLVER',p_tipo => 'submit',p_titulo=> '',p_valor => '1',p_desabilitado =>'N'),'>',' formnovalidate>')||'</td>');
    --else
    --  add('<td width="1" align="right">');
    --  add('<a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
    --  add('</td>');
    --end if;
    
    add('</tr>');
    ADD('</thead>');
    ADD('<tbody>');

    -- si es un detalle, mostrar como primera columna la descripcion de su maestro
    if (g_pagina.id_maestro is not null) then
      declare
        m_qry         varchar2(1000);
        m_titulo      varchar2(100);
        m_descripcion varchar2(1000);
      begin
        -- los elementos dinámicos "campo_descripcion","consultar" y "campo_id" vienen de la tabla inv_db.man_paginas_t y no son input del usuario
        select 'select '||campo_descripcion||' '
            || 'from ('||consultar||') '
            || 'where '||campo_id||'=:ID_MAESTRO'
             , singular
        into m_qry, m_titulo
        from inv_db.man_paginas_t
        where id_pagina = g_pagina.id_maestro;

        m_descripcion := ejecutar(m_qry);

        ADD('<tr>');
        ADD('<td width="1" class="label_left">'||m_titulo||':</td>');
        ADD('<td colspan="2"><span class="label_top">'||m_titulo||':<br></span>'||m_descripcion||'</td>');
        ADD('</tr>');
      exception when others then
        null;
      end;
    end if;

    for i in 1..g_columnas.count loop
      v_grupo     := null;
      v_control   := null;
      v_sql       := null;
      begin
        v_valor     := g_registro(g_columnas(i).columna);
      exception when others then
        v_valor     := null;
      end;

      --Preguntamos si la pagina se renderiza en la VER.
      if (g_columnas(i).ver in('S','V')) then
        declare
          m_cond char(1);
        begin
          -- si la condicion_ver esta llena, determinar su valor
          if (g_columnas(i).condicion_ver is not null) then
            m_cond := nvl(ejecutar(g_columnas(i).condicion_ver,null,null),'N'); -- si hay condicion pero devuelve null o ningun registro, no mostrarlo
          else
            m_cond := 'S'; -- si no hay condicion, mostrar el campo
          end if;

          -- si la condicion devuelve S renderizar el campo
          if (m_cond='S') then
            if (lower(substr(g_columnas(i).columna,1,2))='p_') then
              v_name := 'TXT_'||upper(substr(g_columnas(i).columna,3));
            else
              v_name := 'TXT_'||upper(g_columnas(i).columna);
            end if;
            v_label := g_columnas(i).titulo||':';

          --Preguntamos el tipo de dato, dependiendo de, se renderizan los controles
            if(g_columnas(i).tipo_de_dato = 'CHK') then
              v_control := v_control||case when v_valor = 'S' then ' &#x2611; ' else ' &#x2610; ' end;
            elsif(g_columnas(i).tipo_de_dato = 'ICON') then
              v_control := v_control ||'<img src="/_images/'||v_valor||'.png" />';
            elsif(g_columnas(i).tipo_de_dato = 'PASS') then
              v_control := v_control||regexp_replace(v_valor, '\w', '*');
            elsif(g_columnas(i).tipo_de_dato = 'MCHK') then
              v_valor := 'S';
            elsif(g_columnas(i).tipo_de_dato in('HTML','CODE','DOWN')) then
              --  v_control := v_control ||g_registro(g_columnas(i).columna);
              v_control := v_control ||input_control(P_nombre =>v_name,
                                                     p_tipo             => g_columnas(i).tipo_de_dato,
                                                     p_requerido        => 'N',
                                                     p_placeholder      => null,
                                                     p_valor            => case when g_columnas(i).tipo_de_dato='DOWN' then g_columnas(i).valor_default else v_valor end,
                                                     p_longitud         => null,
                                                     p_regexp_val       => null,
                                                     p_regexp_msg       => null,
                                                     p_estilo           => g_columnas(i).estilo_ver,
                                                     p_autopostback     => g_columnas(i).autopostback,
                                                     p_lista_de_valores => g_columnas(i).lista_de_valores
                                                     );
            elsif(g_columnas(i).tipo_de_dato in('IMG')) then
              -- ver si está en el registro de esta tabla (cargada desde antes)
              declare
                m_sql varchar2(32000);
              begin
                m_sql := 'select '||replace(v_name,'TXT_','')||' from ('||g_pagina.consultar||') where '||g_pagina.campo_id||'=:id';
                if (lower(m_sql) like '%:id_inventario%') then
                  execute immediate  m_sql into m_blob  using g_id_inventario,sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
                else
                  execute immediate  m_sql into m_blob  using sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
                end if;
              end;

              v_control := v_control
                        ||'<img id="'||v_name||'_JPG" style="width:98%; max-width:500px; display:block;"'
                        ||' src="'||case when m_blob is null then '' else 'data:image/jpeg;base64,'||inv_db.man_formatear_pkg.base64encode(m_blob) end||'"'
                        ||' alt="">';
            elsif(g_columnas(i).tipo_de_dato in('FIRMA')) then
              -- ver si está en el registro de esta tabla (cargada desde antes)
              declare
                m_sql varchar2(32000);
              begin
                m_sql := 'select '||replace(v_name,'TXT_','')||' from ('||g_pagina.consultar||') where '||g_pagina.campo_id||'=:id';
                if (lower(m_sql) like '%:id_inventario%') then
                  execute immediate m_sql into v_valor  using g_id_inventario,sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
                else
                  execute immediate m_sql into v_valor  using sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
                end if;
              end;
              v_control := v_control||'<img src="'||v_valor||'" alt="">';
            else
              v_control := v_control ||input_control(P_nombre =>v_name,
                                                         p_tipo            => 'LBL', --g_columnas(i).tipo_de_dato,
                                                         p_requerido       => 'N',
                                                         p_placeholder     => null,
                                                         p_valor           => case when lower(substr(g_columnas(i).columna,1,2))='p_' then null else v_valor end,
                                                         p_longitud        => null,
                                                         p_regexp_val      => null,
                                                         p_regexp_msg      => null,
                                                         p_estilo          => g_columnas(i).estilo_ver,
                                                         p_lista_de_valores=> case
                                                                              when g_columnas(i).tipo_de_dato='LBL'
                                                                              then g_columnas(i).lista_de_valores -- es un LBL+LOV para traer el valor
                                                                              else null                           -- no lo es, se mostrará la expresion
                                                                              end
                                                     );

              -- v_control := v_control ||HTF.ESCAPE_SC(g_registro(g_columnas(i).columna));
            end if;

              --Buscamos la vista y armamos el query renderizar la lista de checkboxes
              if(g_columnas(i).tipo_de_dato = 'MCHK') then
                v_sql := g_columnas(i).lista_de_valores;
                v_sql := 'select * from '||v_sql|| ' where id_registro = '||sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO');

              --Llamamos la función que escribe las listas de valores
                v_control := v_control || lista_de_valores(v_name,
                                                                 v_sql,
                                                                 null,
                                                                 v_valor,
                                                                 'S',
                                                                 g_columnas(i).tipo_de_dato,
                                                                 g_columnas(i).autopostback);
              end if;

             --Preguntamos si la pagina agrupa controles
              if(g_columnas(i).grupo) is not null then
                m_grupo := g_columnas(i).grupo;

                select min(d.secuencia) min_seq
                into v_min_seg
                from man_det_columnas_paginas_t d
                where d.grupo = m_grupo
                  and d.id_pagina=  g_columnas(i).id_pagina;

                if(g_columnas(i).secuencia = v_min_seg) then
                    v_grupo := '<tr class="grupo" >'
                            || '<td colspan="2">'||g_columnas(i).grupo||'</td>'
                            || '<td><img src="/_images/expand_less.png"/></td>'
                            || '</tr>';
                end if;
                if (v_grupo is not null) then
                  ADD(v_grupo);
                end if;
              end if;

              --agregar el prefijo y el sufijo antes y despues del control
              v_control := case when g_columnas(i).prefijo is not null then g_columnas(i).prefijo||'&nbsp;' else '' end
                        || v_control
                        || case when g_columnas(i).sufijo  is not null then '&nbsp;'||g_columnas(i).sufijo else '' end;

              if (nvl(v_valor,'~')<>chr(8)) then
                if (g_columnas(i).layout is null) then
                  ADD('<tr>');
                  ADD('<td width="1" class="label_left">'||v_label||'</td>');
                  ADD('<td colspan="3"><span class="label_top">'||v_label||'<br></span>'||v_control||'</td>');
                  ADD('</tr>');
                else
                  if (g_columnas(i).layout in('L')) then
                    ADD('<tr>');
                    ADD('<td width="1" class="label_left">'||v_label||'</td>');
                    ADD('<td colspan="3">');
                  end if;

                  add(v_control);

                  if (g_columnas(i).layout in('R')) then
                    ADD('</td>');
                    ADD('</tr>');
                  end if;
                end if;
              end if;
            end if;
          end;
      end if;
      --
    end loop;
    ADD('</tbody>');

    --botones
    if (g_reportes.count>0) then
      ADD('<tfoot>');
      ADD('<tr>');
      ADD('<td colspan="3" align="right">');
      --- Reportes de la pagina, se muestran todos, los de seleccion multiple o no
      for i in 1 .. g_reportes.count loop
          add(boton(p_icono =>  'print',
                       p_nombre => 'BTN_REPORTE_'|| encrypt(g_reportes(i).id_reporte),
                       p_tipo =>   'submit',
                       p_titulo=>   g_reportes(i).reporte,
                       p_valor =>   encrypt(g_reportes(i).id_reporte),
                       p_desabilitado => 'N',
                       p_confirmacion => ' onclick="return confirm(''¿Seguro que desea imprimir este registro?'');"'));

      end loop;
      ADD('</td>');
      ADD('</tr>');
      ADD('</tfoot>');
    end if;

    ADD('</table>');
    
    ADD('<script language="javascript">');
    ADD('    jQuery.noConflict();');
    ADD('    jQuery(document).ready(function($) {');
    ADD('        $(''.grupo'').click(function(){');
    ADD('          $(this).find(''span'').text(function(_, value){return value==''expand_less''?''expand_more'':''expand_less''});');
    ADD('          $(this).nextUntil(''tr.grupo'').slideToggle(100, function(){');
    ADD('        });');
    ADD('      });');
    if (g_pagina.javascript is not null) then
      add(g_pagina.javascript);
    end if;
    ADD('    });');
    ADD('  </script>');
  end ver;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar el html necesario para editar un registro de la página actual
  */
  procedure modificar is
     v_label          varchar2(1000);
     v_control        clob;
     v_valor          clob;
     v_sub_label      varchar2(500);
     v_tipo_dato      varchar2(500);
     v_name           varchar2(2000);
     v_grupo          varchar2(500);
     m_grupo          varchar2(500);
     v_min_seg        number;
     v_jq_lov         varchar2(2000);
     v_sub_valor      varchar2(2000);
     v_sub_sql        varchar2(2500);
     v_sub_name       varchar2(2000);
     v_lov_sql        clob;
     v_lov_cant       number;
     v_poner_data     char(1) := 'S';
     v_nulls          char(1);

     m_disable_save   varchar2(1) := 'N';

     m_cond_read_only varchar2(1);
     m_msg_read_only  varchar2(500);
     m_label_boton    varchar2(100) := 'Guardar';

     m_consulta_lista   clob;
     m_maestro_id       varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');
     tmp_clob           clob;

  begin
    --log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Modificar');
    g_registro       := registro('N');

    -- default button
    ADD(boton(p_icono => null ,p_nombre => 'BTN_MODIFICAR' , p_tipo => 'submit', p_titulo => null , p_valor => null, p_desabilitado => 'N', p_estilo => 'visibility: hidden !important;'));
    add('<input type="hidden" name="'||inv_db.seg_autenticacion_pkg.md5('upd')||'">');
    ADD('<table id="ventana" class="editar">');
    ADD(' <thead>');

     if (g_pagina.tipo ='E' and g_pagina.id_maestro is not null and g_tabs.count>0) then
       -- tomar el ultimo segmento de owner.package.procedure del valor de man_paginas_t.agregar
       with rws as (select g_pagina.modificar str from dual),
       tmp as (select rownum rnum,regexp_substr (str,'[^.]+',1,level) value from rws connect by level <= length(str)-length(replace(str,'.'))+1)
       select initcap(replace(value,'_',' ')) into m_label_boton from tmp where rnum=(select max(rnum) from tmp);

       add('<tr>');
       add('<td colspan="'||(10)||'">');
       add('<table>');
       add('<tr>');
       add('<th width="*" id="consultar_titulo" >');
       if g_pagina.id_maestro is null then
          add(g_pagina.titulo);
       else
          if g_tabs.count > 1 then
             add(g_maestro.singular);
          else
             add(g_pagina.plural||' de ' ||g_maestro.singular);
         end if;

         if (sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO') is not null) and (m_maestro_id is null) then
            m_maestro_id := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO');
         end if;

         declare
           m_regs int;
         begin
           -- el elemento dinámico "p_maestro.consultar" viene de inv_db.man_paginas_t y no es input del usuario
           m_regs := ejecutar('select count(*) FROM ('||g_maestro.consultar||')');

           if (m_regs <= 500) then
             -- los elementos dinamicos "p_maestro.campo_id","p_maestro.campo_descripcion","p_maestro.consultar" vienen de man_paginas_t y no son input del usuario
             m_consulta_lista := 'select '||g_maestro.campo_id||','|| g_maestro.campo_descripcion ||' FROM ('||g_maestro.consultar||') ORDER BY '||g_maestro.campo_descripcion;
             v_jq_lov := v_jq_lov ||'$("#LOV_MAESTRO").select2({width:''width:100%;''}); ';
             tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'N',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'S');
           else
             -- los elementos dinamicos "p_maestro.campo_id","p_maestro.campo_descripcion","p_maestro.consultar" vienen de man_paginas_t y no son input del usuario
             m_consulta_lista:= 'select '||g_maestro.campo_id||','|| g_maestro.campo_descripcion ||' FROM ('||g_maestro.consultar||') where '||g_maestro.campo_id||'='''||m_maestro_id||'''';
             v_jq_lov := v_jq_lov ||'$("#LOV_MAESTRO").select2({width:''width:100%;''}); ';
             tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'S',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'N');
           end if;
           add(tmp_clob);

           -- si por algun motivo el valor seleccionado no está en la lista, seleccionar el primero y cambiar el id_maestro
           if (m_maestro_id is null or tmp_clob not like '%value="'||m_maestro_id||'"%') then
             declare
               m_tmp clob;
             begin
               m_tmp        := substr(tmp_clob, instr(tmp_clob,'<option value="')+15);  -- este clob empieza en el valor del primer option
               m_maestro_id := substr(m_tmp,1,instr(m_tmp,'"')-1);                      -- este es el valor del primer option
               sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'ID_MAESTRO',m_maestro_id);
             end;
           end if;

         end;
       end if;
       add('</th>');

       add('   <th width="1" align="right">');
       if g_pagina.documentacion is not null then
          add(boton(p_icono => 'help_center',
                          p_nombre => 'BTN_AYUDA',
                          p_tipo => 'submit',
                          p_titulo=> '',
                          p_valor => 'ayuda',
                          p_desabilitado =>'N'));
       end if;
       add('</th>');
       if g_tabs.count > 0 then
          add('   <th width="1" align="right">');
          add(replace(boton(p_icono => 'arrow_back_ios_new',
                                  p_nombre => 'BTN_REGRESAR',
                                  p_tipo => 'submit',
                                  p_titulo=> '',
                                  p_valor => encrypt(g_pagina.id_maestro),
                                  p_desabilitado =>'N')
                      ,'>',' formnovalidate>'));
          add('</th>');
       else
          add('   <th width="1" align="right">');
          add('   <a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
          add('   </th>');
       end if;

      add('</tr>');
      add('</table>');
      add('</td>');
      add('</tr>');

      add(tabs(p_column_count => 10));
    else
      ADD('  <tr>');
      add('   <td width="*" colspan="2" id="consultar_titulo">Modificar '||g_pagina.singular||':</td>');
      if (g_pagina.tipo='E') then
        add('   <th width="1" align="right">');
        add('   <a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
        add('   </th>');
      else
        ADD('   <td width="1" align="right">'||replace(boton(p_icono => 'arrow_back_ios_new',p_nombre => 'BTN_VOLVER',p_tipo => 'submit',p_titulo=> '',p_valor => '1',p_desabilitado =>'N'),'>',' formnovalidate>')||'</td>');
      end if;
      add('  </tr>');
    end if;

    ADD(' </thead>');
    ADD(' <tbody>');
    add('  <tr><td colspan="3" style="padding:0px;">');
    add('   <table border="0" cellspacing="0" cellpadding="0" style="width:100%; border-collapse:collapse;">');

    -- si es un detalle, mostrar como primera columna la descripcion de su maestro
    if (g_pagina.id_maestro is not null and g_pagina.tipo not in('A','E')) then
      declare
        m_qry         varchar2(1000);
        m_titulo      varchar2(100);
        m_descripcion varchar2(1000);
      begin
        -- los elementos dinamicos "campo_descripcion","consultar" y "campo_id" vienen de inv_db.man_paginas_t y no son input del usuario
        select 'select '||campo_descripcion||' '
            || 'from ('||consultar||') '
            || 'where '||campo_id||'=:ID_MAESTRO'
             , singular
        into m_qry, m_titulo
        from inv_db.man_paginas_t
        where id_pagina = g_pagina.id_maestro;

        -- el input del usuario ":id_maestro" se envía parametizado
        m_descripcion := ejecutar(m_qry);

        ADD('<tr id="TR_MASTER">');
        ADD('<td width="1" class="label_left">'||m_titulo||':</td>');
        ADD('<td colspan="2"><span class="label_top">'||m_titulo||':<br></span>'||m_descripcion||'</td>');
        --ADD('<td><div class="label_top">'||m_titulo||':</div>'||m_descripcion||'</td>'); -- aqui habia un span con un br
        ADD('</tr>');
      exception when others then
        null;
      end;
    end if;

    --*************************************************************************************
    if (g_pagina.tipo in('A','E')) then
      -- usar condicion_read_only para llenar la variable m_cond_read_only
      m_cond_read_only := null;
      if (g_pagina.condicion_solo_lectura is null) then
        m_cond_read_only := 'N';
        m_msg_read_only  := null;
      else
        -- el elemento dinamico "g_pagina.condicion_solo_lectura" viene de inv_db.man_paginas_t y no es input del usuario
        if (g_pagina.tipo='E') then
          m_cond_read_only := ejecutar('select '||g_pagina.condicion_solo_lectura||' as condicion from ('||g_pagina.consultar||')');
        else
          m_cond_read_only := ejecutar('select '||g_pagina.condicion_solo_lectura||' as condicion from dual');
        end if;
        m_msg_read_only  := g_pagina.mensaje_solo_lectura;
      end if;
    end if;

    if (m_cond_read_only is not null and m_cond_read_only='S') then
      if (m_msg_read_only is null) then
        add('<tr><td><div id="chart-container"><b>No es posible '||lower(m_label_boton)||' este registro.</b></div></td></tr>');
      else
        add('<tr><td><div id="chart-container"><b>'||m_msg_read_only||'</b></div></td></tr>');
      end if;
    else
        for i in 1..g_columnas.count loop
          v_valor     := null;
          v_grupo     := null;
          v_sub_label := null;
          v_control   := null;
          v_sub_sql   := null;
          v_sub_name  := null;
          v_lov_sql   := null;
          v_lov_cant  := null;
          v_nulls     := case when g_columnas(i).requerido='S' then 'S' else 'N' end;

          if (g_columnas(i).modificar='S' or g_columnas(i).ver in('S','M')) then
            declare
              m_cond char(1);
            begin
              -- si la condicion_ver esta llena, determinar su valor
              if (g_columnas(i).condicion_modificar is not null) then
                m_cond := nvl(ejecutar(g_columnas(i).condicion_modificar,null,null),'N'); -- si hay condicion pero devuelve null o ningun registro, no mostrarlo
              else
                m_cond := 'S'; -- si no hay condicion, mostrar el campo
              end if;

              -- si la condicion devuelve S renderizar el campo
              if (m_cond='S') then
                if (substr(lower(g_columnas(i).columna),1,2)='p_') then
                  v_name := 'TXT_'||upper(substr(g_columnas(i).columna,3));
                else
                  v_name := 'TXT_'||upper(g_columnas(i).columna);
                end if;
                v_label := g_columnas(i).titulo||':';

                --Ver si es la primera vez que entramos a esta pagina, para solo asi poner defaults
                if (v_poner_data='S' and g_columnas(i).tipo_de_dato not in ('CHK','MCHK') and g_formulario.exists(v_name)) then
                  v_poner_data := 'N';
                  v_nulls      := 'N';
                end if;

                --Si el formulario viene lleno
                if (g_formulario.exists(v_name)) then
                  if (g_columnas(i).tipo_de_dato='CHK') then
                    v_valor := 'S';
                  elsif (g_columnas(i).tipo_de_dato='FEC') then
                    v_valor := man_formatear_pkg.y_m_d(g_formulario(v_name));
                  elsif (g_columnas(i).tipo_de_dato in('DEC','FLOAT')) then
                    v_valor := replace(g_formulario(v_name),',','');
                  else
                    v_valor := g_formulario(v_name);
                  end if;
                elsif (g_registro.exists(g_columnas(i).columna)) then
                  if (g_columnas(i).tipo_de_dato = 'FEC') then
                     v_valor := man_formatear_pkg.y_m_d(to_date(g_registro(g_columnas(i).columna))); --ignore este warning: es necesario para ver si es una fecha valida
                  else
                    v_valor := g_registro(g_columnas(i).columna);
                  end if;
                end if;
                
                if (g_columnas(i).tipo_de_dato in('DOC','HTML')) then
                  if (g_columnas(i).valor_default is not null and (lower(g_columnas(i).valor_default) like 'select %' or lower(v_valor) like 'with %')) then
                    if (lower(g_columnas(i).valor_default) like '%:id_registro%') then
                      execute immediate g_columnas(i).valor_default 
                      into v_valor
                      using sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO');
                    elsif (lower(g_columnas(i).valor_default) like '%:id_usuario%') then
                      execute immediate g_columnas(i).valor_default 
                      into v_valor
                      using g_id_usuario_procesa;
                    else
                      execute immediate g_columnas(i).valor_default 
                      into v_valor;
                    end if;
    --              else 
    --                v_valor := g_columnas(i).valor_default;
                  end if;
                end if;

                if(g_columnas(i).modificar='N' and g_columnas(i).ver in('S','M')) then
                  if (g_columnas(i).tipo_de_dato in('ICON','HTML','CODE','DOWN')) then
                      v_tipo_dato := g_columnas(i).tipo_de_dato;
                  else
                      v_tipo_dato := 'LBL';
                  end if;
                else
                  v_tipo_dato := g_columnas(i).tipo_de_dato;
                end if;

                v_sub_valor := null;
                v_sub_sql   := g_columnas(i).lista_de_valores;
                if (lower(v_sub_sql) like 'select %' or lower(v_sub_sql) like 'with %') then
                  if (g_columnas(i).tipo_de_dato = 'MCHK') then
                    v_sub_sql := 'select * from ('||v_sub_sql||') where id_registro=:ID_REGISTRO order by descripcion';
                  end if;
                end if;

                if(v_tipo_dato in ('LBL','TXT','ICON','PASS','NUM','DEC','FLOAT','FEC','HORA','CHK','MEMO','IMG','DOC','HTML','CODE','DOWN','FIRMA')) then
                    v_control := v_control || input_control(v_name,
                                               v_tipo_dato,
                                               g_columnas(i).requerido,
                                               case when v_tipo_dato='DOC'  then g_columnas(i).valor_default else null    end,
                                               case when v_tipo_dato='DOWN' then g_columnas(i).valor_default else v_valor end,
                                               g_columnas(i).longitud,
                                               g_columnas(i).regexp_validacion,
                                               g_columnas(i).regexp_mensaje,
                                               g_columnas(i).estilo_modificar,
                                               g_columnas(i).autopostback,
                                               g_columnas(i).lista_de_valores);

                     -- ver si no trajo el valor de buscar para apagar el boton de guardar
                     if (g_columnas(i).modificar='S'
                     and g_columnas(i).tipo_de_dato='TXT'
                     and g_columnas(i).autopostback='S'
                     and g_columnas(i).lista_de_valores is not null
                     and g_columnas(i).requerido='S'
                     and v_control not like '%DESC_'||v_name||'%'
                     ) then
                       m_disable_save := 'S';
                     end if;
                  elsif(g_columnas(i).tipo_de_dato in ('RAD','LOV','MULTI','MCHK','OL','UL')) then
                    v_control := v_control || lista_de_valores(
                      v_name,
                      v_sub_sql,
                      v_nulls,
                      v_valor,
                      'N',
                      g_columnas(i).tipo_de_dato,
                      g_columnas(i).autopostback,
                      g_columnas(i).estilo_modificar
                    );

                    --Si la cantidad de items en una lista supera los 10 registros no agregamos el search sobre la listas
                    if(g_columnas(i).tipo_de_dato in('LOV','MULTI')) then
                      v_jq_lov := v_jq_lov ||'$("#'||v_name||'").select2('||g_select2_params||');';
                    end if;
                  end if;

                  --agregar el prefijo y el sufijo antes y despues del control
                  v_control := case when g_columnas(i).prefijo is not null then g_columnas(i).prefijo||'&nbsp;' else '' end
                            || v_control
                            || case when g_columnas(i).sufijo  is not null then '&nbsp;'||g_columnas(i).sufijo else '' end;

                  --v_control := '<div style="display:inline-block;">'||v_control||'</div>';
                  if (g_columnas(i).grupo) is not null then
                    m_grupo := g_columnas(i).grupo;
                    select min(d.secuencia) min_seq
                    into v_min_seg
                    from man_det_columnas_paginas_t d
                    where d.grupo = m_grupo
                      and d.id_pagina=  g_columnas(i).id_pagina;
                    if (g_columnas(i).secuencia = v_min_seg) then
                          v_grupo := '<tr><td colspan="3" style="height:5px;"></td></tr>'
                                  || '<tr  id="TR_'||upper(replace(g_columnas(i).grupo,' ','_'))||'" class="grupo">'
                                  || '<td colspan="2" width="*">'||g_columnas(i).grupo||'</td>'
                                  || '<td width="1"><img src="/_images/expand_less.png" /></td>'
                                  || '</tr>'
                                  || '<tr><td colspan="3" style="height:5px;"></td></tr>';

                    end if;
                    if (v_grupo is not null) then
                      ADD(v_grupo);
                    end if;
                  end if;

                  if (nvl(v_valor,'~')<>chr(8)) then -- esto es para que cuando no se quiera renderizar un campo se mande chr(8) en su valor
                    if (g_columnas(i).layout is null) then
                      ADD('<tr id="TR_'||g_columnas(i).columna||'">');
                      ADD('<td width="1" class="label_left">'||v_label||'</td>');
                      ADD('<td colspan="3"><div class="label_top">'||v_label||'</div>'||v_control||'</td>'); -- span con br
                      ADD('</tr>');
                    else
                      if (g_columnas(i).layout in('L')) then
                        ADD('<tr id="TR_'||g_columnas(i).columna||'">');
                        ADD('<td width="1" class="label_left">'||v_label||'</td>');
                        ADD('<td colspan="3"><div class="label_top">'||v_label||'</div>'); --span con br
                      end if;

                      add(v_control);

                      if (g_columnas(i).layout='R') then
                        ADD('</td>');
                        ADD('</tr>');
                      end if;
                    end if;
                  end if;
                end if;
             end;
          end if;
          --
        end loop;
   --*******************
    end if;
    add(' </table');
    add(' </td></tr>');
    ADD('</tbody>');
    ADD('<tfoot>');
    --botones
    ADD('<tr>');

    ADD('<td align="left">');
    --- Reportes de la pagina, se muestran todos, los de seleccion multiple o no
    for i in 1 .. g_reportes.count loop
        add(boton(p_icono =>  'print',
                     p_nombre => 'BTN_REPORTE_'|| encrypt(g_reportes(i).id_reporte),
                     p_tipo =>   'submit',
                     p_titulo=>   g_reportes(i).reporte,
                     p_valor =>   encrypt(g_reportes(i).id_reporte),
                     p_desabilitado => 'N',
                     p_confirmacion => ' onclick="return confirm(''¿Seguro que desea imprimir este registro?'');"'));

    end loop;
    ADD('</td>');

    ADD('<td colspan="2" align="right">');
    if (m_cond_read_only is null or m_cond_read_only='N') then
      ADD(boton(p_icono => 'done' ,p_nombre => 'BTN_MODIFICAR' , p_tipo => 'submit', p_titulo => m_label_boton , p_valor => '', p_desabilitado => m_disable_save));
    end if;
    ADD('</td>');

    ADD('</tr>');
    ADD('</tfoot>');
    ADD('</table>');
    ADD('<script language="javascript">');
    ADD('  jQuery.noConflict();');
    add('');
    -- el manejo de colapsar grupos
    add('  jQuery(document).ready(function($) {');
    add('  '||v_jq_lov);
    if (g_resultado like '%class="fecha"%') then
      add('   $(".fecha").datepicker({
                onSelect: function(date) {document.forms["mainForm"].submit();},
                dateFormat: "dd/mm/yy",
                dayNamesMin: [ "Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sa" ],
                dayNamesShort: [ "Dom", "Lun", "Mar", "Mie", "Jue", "Vie", "Sab" ],
                monthNames: [ "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                });');
    end if;
    add('  $(''.grupo'').click(function(){');
    add('    $(this).find(''span'').text(function(_, value){return value==''expand_less''?''expand_more'':''expand_less''});');
    add('    $(this).nextUntil(''tr.grupo'').slideToggle(100, function(){});');
    add('  });');
    if (g_pagina.javascript is not null) then
      add(g_pagina.javascript);
    end if;
    add('');
    add('  });');
    add('');
    if (g_resultado like '%upload_check(%') then
     add('
      function upload_check(ctrl) {
        if(ctrl.files[0].size < 1) {
           ctrl.value = null;
           swal({text:"El archivo seleccionado no contiene ningún dato.",icon:"error"});
        } else if(ctrl.files[0].size > 15000001) {
           ctrl.value = null;
           swal({text:"El archivo no debe sobrepasar los 15mb.",icon:"error"});
        }
      };');
    end if;
    add('</script>');
  end modificar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar el html necesario para agregar un registro de la página actual
  */
  procedure agregar is
    v_label          varchar2(500);
    v_control        clob;
    v_name           varchar2(2000);
    v_valor          clob;
    v_sql            varchar2(500);
    v_tipo_dato      varchar2(500);
    v_min_seq        number;
    v_jq_lov         varchar2(4000);
    v_sub_valor      varchar2(500) := null;
    v_sub_sql        varchar2(2500);
    v_sub_name       varchar2(200);
    v_lov_sql        clob;
    v_lov_cant       number;
    v_poner_defaults char(1) := 'S';
    m_disable_save   varchar2(1) := 'N';

    m_cond_read_only varchar2(1);
    m_msg_read_only  varchar2(500);
    m_label_boton    varchar2(100) := 'Guardar';

    m_consulta_lista   clob;
    m_maestro_id       varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');
    tmp_clob           clob;

  begin
    --log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Agregar');

    ADD(boton(p_icono => null ,p_nombre => 'BTN_INSERTAR'  , p_tipo => 'submit', p_titulo => null , p_valor => null, p_desabilitado => 'N', p_estilo => 'visibility: hidden !important;'));
    add('<input type="hidden" name="'||inv_db.seg_autenticacion_pkg.md5('add')||'">');
    ADD('<table id="ventana" class="editar">');
    ADD(' <thead>');

    if (g_pagina.tipo='A' and g_pagina.id_maestro is not null and g_tabs.count>0) then
       -- tomar el ultimo segmente de owner.package.procedure del valor de man_paginas_t.agregar
       with rws as (select g_pagina.agregar str from dual),
       tmp as (select rownum rnum,regexp_substr (str,'[^.]+',1,level) value from rws connect by level <= length(str)-length(replace(str,'.'))+1)
       select initcap(replace(value,'_',' ')) into m_label_boton from tmp where rnum=(select max(rnum) from tmp);

       add('<tr>');
       add('<td colspan="'||(10)||'">');
       add('<table>');
       add('<tr>');
       add('<th width="*" id="consultar_titulo" >');
       if g_pagina.id_maestro is null then
          add(g_pagina.titulo);
       else
          if g_tabs.count > 1 then
             add(g_maestro.singular);
          else
             add(g_pagina.plural||' de ' ||g_maestro.singular);
         end if;

         --
         if (sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO') is not null) and (m_maestro_id is null) then
            m_maestro_id := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO');
         end if;

         declare
           m_regs int;
         begin
           -- el elemento dinámico "g_maestro.consultar" viene de inv_db.man_paginas_t y no es input del usuario
           m_regs := ejecutar('select count(*) FROM ('||g_maestro.consultar||')');

           if (m_regs <= 500) then
             -- los elementos dinamicos "g_maestro.campo_id","g_maestro.campo_descripcion","g_maestro.consultar" vienen de man_paginas_t y no son input del usuario
             m_consulta_lista := 'select '|| g_maestro.campo_id||','|| g_maestro.campo_descripcion ||' FROM ('||g_maestro.consultar||') ORDER BY '||g_maestro.campo_descripcion;
             v_jq_lov := v_jq_lov ||'$("#LOV_MAESTRO").select2({width:''width:100%;''}); ';
             tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'N',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'S');
           else
             -- los elementos dinamicos "g_maestro.campo_id","g_maestro.campo_descripcion","g_maestro.consultar" vienen de man_paginas_t y no son input del usuario
             m_consulta_lista:= 'select '||g_maestro.campo_id||','|| g_maestro.campo_descripcion ||' FROM ('||g_maestro.consultar||') where '||g_maestro.campo_id||'='''||m_maestro_id||'''';
             v_jq_lov := v_jq_lov ||'$("#LOV_MAESTRO").select2({width:''width:100%;''}); ';
             tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'S',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'N');
           end if;
           add(tmp_clob);

           -- si por algun motivo el valor seleccionado no está en la lista, seleccionar el primero y cambiar el id_maestro
           if (m_maestro_id is null or tmp_clob not like '%value="'||m_maestro_id||'"%') then
             declare
               m_tmp clob;
             begin
               m_tmp        := substr(tmp_clob, instr(tmp_clob,'<option value="')+15);  -- este clob empieza en el valor del primer option
               m_maestro_id := substr(m_tmp,1,instr(m_tmp,'"')-1);                      -- este es el valor del primer option
               sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'ID_MAESTRO',m_maestro_id);
             end;
           end if;

         end;
       end if;
       add('</th>');

       add('   <th width="1" align="right">');
       if g_pagina.documentacion is not null then
          add(boton(p_icono => 'help_center',
                          p_nombre => 'BTN_AYUDA',
                          p_tipo => 'submit',
                          p_titulo=> '',
                          p_valor => 'ayuda',
                          p_desabilitado =>'N'));
       end if;
       add('</th>');
       add('   <th width="1" align="right">');
       add(replace(boton(p_icono => 'arrow_back_ios_new',
                               p_nombre => 'BTN_REGRESAR',
                               p_tipo => 'submit',
                               p_titulo=> '',
                               p_valor => encrypt(g_pagina.id_maestro),
                               p_desabilitado =>'N')
                   ,'>',' formnovalidate>'));
       add('</th>');
      add('</tr>');
      add('</table>');
      add('</td>');
      add('</tr>');

      add(tabs(p_column_count => 10));
    else
      ADD('  <tr>');
      add('   <td width="*" colspan="2" id="consultar_titulo">Agregar '||g_pagina.singular||':</td>');
      add('   <th width="1" align="right">');
      if (g_pagina.tipo='A') then
        add('   <a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
      else
        ADD(replace(boton(p_icono => 'arrow_back_ios_new',p_nombre => 'BTN_VOLVER',p_tipo => 'submit',p_titulo=> '',p_valor => '1',p_desabilitado =>'N'),'>',' formnovalidate>'));
      end if;
      add('   </th>');
      add('  </tr>');
    end if;

    ADD(' </thead>');
    ADD(' <tbody>');
    add('  <tr><td colspan="3" style="padding:0px;">');
    add('   <table border="0" cellspacing="0" cellpadding="0" style="width:100%; border-collapse:collapse;">');

    -- si es un detalle, mostrar como primera columna la descripcion de su maestro
    if (g_pagina.id_maestro is not null and g_pagina.tipo not in('A','E')) then
      declare
        m_qry         varchar2(1000);
        m_titulo      varchar2(100);
        m_descripcion varchar2(1000);
      begin
        -- los elementos dinamicos "campo_descripcion","consultar" y "campo_id" vienen de inv_db.man_paginas_t y no son input del usuario
        select 'select '||campo_descripcion||' '
            || 'from ('||consultar||') '
            || 'where '||campo_id||'=:ID_MAESTRO'
             , singular
        into m_qry, m_titulo
        from inv_db.man_paginas_t
        where id_pagina = g_pagina.id_maestro;

        -- el input del usuario ":id_maestro" se envía parametizado
        m_descripcion := ejecutar(m_qry);

        ADD('<tr id="TR_MASTER">');
        ADD('<td width="1" class="label_left">'||m_titulo||':</td>');
        ADD('<td colspan="2"><span class="label_top">'||m_titulo||':<br></span>'||m_descripcion||'</td>');
        ADD('</tr>');
      exception when others then
        null;
      end;
    end if;

    if (g_pagina.tipo in('A','E')) then
      -- usar condicion_read_only para llenar la variable m_cond_read_only
      m_cond_read_only := null;
      if (g_pagina.condicion_solo_lectura is null) then
        m_cond_read_only := 'N';
        m_msg_read_only  := null;
      else
        -- el elemento dinamico "g_pagina.condicion_solo_lectura" viene de inv_db.man_paginas_t y no es input del usuario
        m_cond_read_only := ejecutar('select '||g_pagina.condicion_solo_lectura||' as condicion from dual');
        m_msg_read_only  := g_pagina.mensaje_solo_lectura;
      end if;
    end if;

    if (m_cond_read_only is not null and m_cond_read_only='S') then
      if (m_msg_read_only is null) then
        add('<tr><td><div id="chart-container"><b>No es posible '||lower(m_label_boton)||' este registro.</b></div></td></tr>');
      else
        add('<tr><td><div id="chart-container"><b>'||m_msg_read_only||'</b></div></td></tr>');
      end if;
    else
      for i in 1..g_columnas.count loop
        --Inicializamos toda las variables necesarias
        v_valor     := null;
        v_control   := null;
        v_label     := null;
        v_sub_valor := null;
        v_sub_sql   := null;
        v_sub_name  := null;
        v_lov_sql   := null;
        v_lov_cant  := null;

        if(g_columnas(i).agregar='S' or g_columnas(i).ver in('S','A')) then
          declare
            m_cond char(1);
          begin
            -- si la condicion_ver esta llena, determinar su valor
            if (g_columnas(i).condicion_agregar is not null) then
              m_cond := nvl(ejecutar(g_columnas(i).condicion_agregar,null,null),'N'); -- si hay condicion pero devuelve null o ningun registro, no mostrarlo.
            else
              m_cond := 'S';                                                          -- si no hay condicion, mostrar el campo
            end if;
            
            -- si la condicion devuelve S renderizar el campo
            if (m_cond='S') then
              if (substr(lower(g_columnas(i).columna),1,2)='p_') then
                v_name := 'TXT_'||upper(substr(g_columnas(i).columna,3));
              else
                v_name := 'TXT_'||upper(g_columnas(i).columna);
              end if;

              -- ver si es la primera vez que entramos a esta pagina, para solo asi poner defaults
              if (v_poner_defaults='S' and g_columnas(i).tipo_de_dato<>'CHK' and g_formulario.exists(v_name)) then
                v_poner_defaults := 'N';
              end if;
              -- excepto cuando sea un lbl o html que busca el mismo su valor
              if (g_columnas(i).tipo_de_dato in('LBL','HTML') and g_columnas(i).valor_default is not null) then
                v_poner_defaults := 'S';
              end if;

              if (g_formulario.exists(v_name)) then
                if (g_columnas(i).tipo_de_dato='CHK') then
                  v_valor := 'S';
                else
                  v_valor := g_formulario(v_name);
                end if;
              elsif (v_poner_defaults='S' and g_columnas(i).valor_default is not null) then
                -- valor_default puede ser: una constante, la palabra max o una consulta dinamica
                if (lower(trim(g_columnas(i).valor_default)) like 'select %' or lower(trim(g_columnas(i).valor_default))='max') then
                  if (lower(trim(g_columnas(i).valor_default)) like 'select %') then
                    -- es una consulta dinamica
                    v_sql := g_columnas(i).valor_default;
                  else
                    -- es la palabra max, convertirla en consulta dinamica, los elementos "g_pagina.campo_id" y "g_pagina.consultar" vienen de man_paginas_t y no son input del usuario
                    v_sql := 'select nvl(max('||g_pagina.campo_id||'),0)+1 from ('||g_pagina.consultar||')';
                  end if;
                  v_valor := ejecutar(v_sql);
                else
                  -- es un valor constante
                  v_valor := g_columnas(i).valor_default;
                end if;
              elsif (g_columnas(i).tipo_de_dato='CHK') then
                v_valor := 'N';
              end if;

              --Si es un grupo, identificamos el minimo de la secuencia
              if (g_columnas(i).grupo is not null) then
                select min(d.secuencia) min_seq
                  into v_min_seq
                  from man_det_columnas_paginas_t d
                 where d.grupo = g_columnas(i).grupo
                   and d.id_pagina=  g_columnas(i).id_pagina;

                if(g_columnas(i).secuencia = v_min_seq) then
                  add('<tr class="grupo">'||
                      '<td width="*" colspan="2">'||g_columnas(i).grupo||'</td>'||
                      '<td width="1"><img src="/_images/expand_less.png" /></td>'||
                      '</tr>');
                end if;
              end if;

              v_label := g_columnas(i).titulo||':';
              if(g_columnas(i).agregar='N' and g_columnas(i).ver in('S','A')) then
                if (g_columnas(i).tipo_de_dato in('ICON','HTML','CODE','DOWN')) then
                    v_tipo_dato := g_columnas(i).tipo_de_dato;
                else
                  v_tipo_dato := 'LBL';
                end if;
              else
                v_tipo_dato := g_columnas(i).tipo_de_dato;
              end if;

              -- encontrar el valor del parametro que requiera la consulta dinamica
              v_sub_valor := null;
              v_sub_sql   := g_columnas(i).lista_de_valores;
              if (lower(v_sub_sql) like 'select %' or lower(v_sub_sql) like 'with %') then
                if (g_columnas(i).tipo_de_dato = 'MCHK') then
                  -- es una consulta dinámica, el elemento dinamico "v_sub_sql" viene de inv_db.man_det_columnas_paginas_t y no es input del usuario
                  v_sub_sql := 'select distinct ''0'' id_registro, id_detalle, descripcion, id_detalle secuencia, ''N'' seleccionado from ('||v_sub_sql|| ') where seleccionado = ''N'' order by descripcion';
                end if;
              end if;

              --Llamamos la función que crea los controles dependiendo el tipo de dato.
              if(v_tipo_dato in ('LBL','TXT','ICON','PASS','NUM','DEC','FLOAT','FEC','HORA','CHK','MEMO','IMG','DOC','HTML','CODE','DOWN','FIRMA')) then
                v_control := input_control(v_name,
                                          v_tipo_dato,
                                          g_columnas(i).requerido,
                                          case when v_tipo_dato='DOC' then g_columnas(i).valor_default else null end,
                                          v_valor,
                                          g_columnas(i).longitud,
                                          g_columnas(i).regexp_validacion,
                                          g_columnas(i).regexp_mensaje,
                                          g_columnas(i).estilo_agregar,
                                          g_columnas(i).autopostback,
                                          v_sub_sql);

               -- ver si no trajo el valor de buscar para apagar el boton de guardar
               if (g_columnas(i).agregar='S'
               and g_columnas(i).tipo_de_dato='TXT'
               and g_columnas(i).autopostback='S'
               and g_columnas(i).lista_de_valores is not null
               and g_columnas(i).requerido='S'
               and v_control not like '%DESC_'||v_name||'%'
               ) then
                 m_disable_save := 'S';
               end if;
             elsif(g_columnas(i).tipo_de_dato IN ('LOV','DAL','RAD','MULTI','MCHK','UL','OL')) then
               v_control := lista_de_valores(v_name,
                                                   v_sub_sql,
                                                   g_columnas(i).requerido,
                                                   v_valor,
                                                   'N',
                                                   g_columnas(i).tipo_de_dato,
                                                   g_columnas(i).autopostback,
                                                   g_columnas(i).estilo_agregar);
               if (g_columnas(i).tipo_de_dato in('LOV','MULTI')) then
                 v_jq_lov := v_jq_lov ||'$("#'||v_name||'").select2('||g_select2_params||');'||chr(10);
               end if;
             end if;

              --agregar el prefijo y el sufijo antes y despues del control
              v_control := case when g_columnas(i).prefijo is not null then g_columnas(i).prefijo||'&nbsp;' else '' end
                        || v_control
                        || case when g_columnas(i).sufijo  is not null then '&nbsp;'||g_columnas(i).sufijo else '' end;

              if (nvl(v_valor,'~')<>chr(8) and v_control <> chr(8)) then
                if (g_columnas(i).layout is null) then
                  ADD('<tr id="TR_'||g_columnas(i).columna||'">');
                  ADD('<td width="1" class="label_left">'||v_label||'</td>');
                  ADD('<td colspan="3"><span class="label_top">'||v_label||'<br></span>'||v_control||'</td>');
                  ADD('</tr>');
                else
                  if(g_columnas(i).layout = 'L') then
                    ADD('<tr id="TR_'||g_columnas(i).columna||'">');
                    ADD('<td width="1" class="label_left">'||v_label||'</td>');
                    ADD('<td colspan="3"><span class="label_top">'||v_label||'<br></span>');
                  end if;
                  ADD(v_control);
                  if(g_columnas(i).layout  = 'R') then
                    ADD('</td>');
                    ADD('</tr>');
                  end if;
                end if;
              end if;
            end if;
          end;
        end if;
        --
      end loop;
    end if;

    add(' </table');
    add(' </td></tr>');
    ADD('</tbody>');
    ADD('<tfoot>');
    --botones
    ADD('<tr>');
    ADD('<td align="right" colspan="3">');

    if (m_cond_read_only is null or m_cond_read_only='N') then
      ADD(boton(p_icono => 'done' ,p_nombre => 'BTN_INSERTAR' , p_tipo => 'submit', p_titulo => m_label_boton , p_valor => '', p_desabilitado => m_disable_save));
    end if;

    ADD('</td>');
    ADD('</tr>');
    ADD('</tfoot>');
    ADD('</table>');

    ADD('<script language="javascript">');
    ADD('  jQuery.noConflict();');
    add('');
    -- el manejo de colapsar grupos
    add('  jQuery(document).ready(function($) {');
    add('  '||v_jq_lov);
    if (g_resultado like '%class="fecha"%') then
      add('    $(".fecha").datepicker({
                onSelect: function(date) {document.forms["mainForm"].submit();},
                dateFormat: "dd/mm/yy",
                dayNamesMin: [ "Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sa" ],
                dayNamesShort: [ "Dom", "Lun", "Mar", "Mie", "Jue", "Vie", "Sab" ],
                monthNames: [ "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                });');
    end if;
    add('  $(''.grupo'').click(function(){');
    add('    $(this).find(''span'').text(function(_, value){return value==''expand_less''?''expand_more'':''expand_less''});');
    add('    $(this).nextUntil(''tr.grupo'').slideToggle(100, function(){});');
    add('  });');
    if (g_pagina.javascript is not null) then
      add(g_pagina.javascript);
    end if;
    add('');
    add('  });');
    add('');
    if (g_resultado like '%upload_check(%') then
     add('
      function upload_check(ctrl) {
        if(ctrl.files[0].size < 1) {
           ctrl.value = null;
           swal({text:"El archivo seleccionado no contiene ningún dato.",icon:"error"});
        }
        if(ctrl.files[0].size > 15000000) {
           ctrl.value = null;
           swal({text:"El archivo no debe sobrepasar los 15mb.",icon:"error"});
        }
      };');
    end if;
    add('</script>');

  end agregar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar un data grid de la página actual
    *            este datagrid muestra los registos de la pagina actual con opcion a filtrar, sortear, imprimir, exportar, cambiar de página, etc
    *            ademas muetra los botones de agregar, borrar y otras acciones de la página, si aplican
  */
  procedure consultar is
    m_consulta         varchar2(4000);
    m_consulta_count   varchar2(4000);
    m_consulta_lista   clob;
    m_alineacion       varchar2(20);
    m_estilo           varchar2(500);
    m_span_abre        varchar2(120);
    m_span_cierra      varchar2(120);
    m_boton_borrar     varchar2(500);
    m_check_borrar     varchar2(500);
    m_boton_detalle    varchar2(500);
    m_boton_agregar    varchar2(500);
    m_boton_imprimir   varchar2(500);
    m_boton_excel      varchar2(500);
    m_colspan          number(13);
    tmp_clob           clob;
    m_maestro_id       varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');

    t_tab_title        varchar2(100);
    t_tab_query        varchar2(2000);
    t_tab_number       varchar2(15);

    m_control          clob;

    --
    l_theCursor        integer default dbms_sql.open_cursor;
    --

    l_columnValue      varchar2(4000);
    l_campo_id_Value   varchar2(4000);
    l_campo_id_Descrip varchar2(4000);
    l_campo_id_ValueEnc varchar2(4000);
    l_columnName       varchar2(2000);
    l_status           integer;
    l_descTbl          dbms_sql.desc_tab;
    l_colCnt           number;
    n                  number;
    m_ordenar_por      varchar2(50);
    m_direccion        varchar2(10) := 'ASC';
    m_column_count     number;
    m_from_consulta    varchar2(4000) := null;
    m_filtro_consulta  varchar2(4000) := null;
    m_filtro_valor     varchar2(4000) := null;
    m_filtros          number := 0;
    m_name             varchar2(100);
    m_name_val         varchar2(4000);
    m_total_registro   varchar2(4000);
    m_lista_de_valores varchar2(4000) := null;
    m_cond_solo_lectura varchar2(1);
    m_check_count      number := 0;
    m_pagesize         number;
    m_pagenum          number;
    m_pagetotal        number;
    m_cant_registro    number:=0;
    m_registro_omitido integer;
    m_headers          number := 0;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : agrega una linea en el html a renderizar
      * @p_text: texto o etiquetas html a renderizar
    */
    procedure add(
      p_text in clob
    ) is
    begin
      g_resultado := g_resultado||p_text||chr(13);
    end;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : dato el nombre una columna, devolver dicho registro de la colección de columnas
      * @p_columna: nombre de la columna
      * @returns una coleccion de las características de renderización de una columna de una página
    */
    function columna(
      p_columna in varchar2
    )
    return man_det_columnas_paginas_t%ROWTYPE is
    begin
      for i in 1..g_columnas.count loop
        if (g_columnas(i).columna = p_columna and g_columnas(i).consultar='S') then
           return g_columnas(i);
        end if;
      end loop;
    end;
  begin
    log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Consultar');
    m_pagesize := 10;

    --- otener el numeros de columnas que se van a consultar
    select count(*)
    into m_column_count
    from man_det_columnas_paginas_t
    where id_pagina = g_pagina.id_pagina
    and consultar = 'S';

    if (g_puede_borrar = 'S' or g_acciones.count > 0 or g_reportes_multi > 0 ) then
      m_column_count := m_column_count + 1;
    end if;
    if (g_puede_ver_tabs > 0) then
      m_column_count := m_column_count + 1;
    end if;
       add('<input type="submit" name="BTN_FILTRAR" style="display:none;">');
       add('<table id="ventana" class="consultar">');

       -- titulo de la pagina
       add('<thead>');
       add('<tr>');
       add('<td colspan="'||(m_column_count)||'">');
       add('<table>');
       add('<tr>');
       add('<th width="*" id="consultar_titulo" >');
       if g_pagina.id_maestro is null then
          add(g_pagina.titulo);
       else
          if g_tabs.count > 1 then
             add(g_maestro.singular);
          else
             add(g_pagina.plural||' en ' ||g_maestro.singular);
         end if;

         if (sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO') is not null) and (m_maestro_id is null) then
            m_maestro_id := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_REGISTRO');
         end if;

         -- esto solo sucede en detalles y SUBDETALLES
         declare
           m_regs int;
         begin
           if sesion_leer(g_id_sesion,g_pagina.id_pagina,'TOTAL_MAESTROS') is not null then
            m_regs := sesion_leer(g_id_sesion,g_pagina.id_pagina,'TOTAL_MAESTROS');
           else
            -- el elemento dinamico "g_maestro.consultar" viene de inv_db.man_paginas_t, no es input del usuario
            m_regs := ejecutar('select count(*) FROM ('||g_maestro.consultar||')');
            if (m_regs > 500) then
              -- si el conteo de maestros da mas de 500, guardalo en sesion para que no vuelvas a hacer ese mismo conteo
              sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'TOTAL_MAESTROS',m_regs);
            end if;
           end if;

           if (m_regs <= 500) then
             -- los elementos dinamicos "g_maestro.campo_id","g_maestro.campo_descripcion" y "g_maestro.consultar" vienen de inv_db.man_paginas_t y no son input del usuario
             m_consulta_lista := 'select '||g_maestro.campo_id||','|| g_maestro.campo_descripcion
                              || ' FROM ('||g_maestro.consultar||')'
                              || ' ORDER BY '||g_maestro.campo_descripcion;
             
             m_lista_de_valores := m_lista_de_valores ||'      $("#LOV_MAESTRO").select2('||g_select2_params||');'||chr(10);
             tmp_clob := lista_de_valores(p_nombre    => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'N',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'S');
           else
             -- si va a tener mas de 500 registros mejor no la ponemos y ponemos un solo registro
             -- los elementos dinamicos "g_maestro.campo_id","g_maestro.campo_descripcion ", y "g_maestro.consultar" vienen de inv_db.man_paginas_t y no son input del usuario
             -- maestro_id es input del usuario y se pasa parametizado
             m_consulta_lista := 'select '||g_maestro.campo_id||','|| g_maestro.campo_descripcion
                              || ' FROM ('||g_maestro.consultar||') '
                              || ' where '||g_maestro.campo_id||'=:ID_MAESTRO';

             m_lista_de_valores := m_lista_de_valores ||'      $("#LOV_MAESTRO").select2('||g_select2_params||');'||chr(10);
             tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                      p_lista_valores => m_consulta_lista,
                                      p_requerido     => '-',
                                      p_seleccionado  => m_maestro_id,
                                      p_deshabilitado => 'S',
                                      p_tipo_dato     => 'LOV',
                                      p_autoposback   => 'N');
           end if;
           add(tmp_clob);

           -- si por algun motivo el valor seleccionado no está en la lista, seleccionar el primero y cambiar el id_maestro
           if (m_maestro_id is null or tmp_clob not like '%value="'||m_maestro_id||'"%') then
             declare
               m_tmp clob;
             begin
               m_tmp        := substr(tmp_clob, instr(tmp_clob,'<option value="')+15);  -- este clob empieza en el valor del primer option
               m_maestro_id := substr(m_tmp,1,instr(m_tmp,'"')-1);                      -- este es el valor del primer option
               sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'ID_MAESTRO',m_maestro_id);
             end;
           end if;

         end;
       end if;
       add('</th>');

       add('   <th width="1" align="right">');
       if g_pagina.documentacion is not null then
          add(boton(p_icono => 'help_center',
                          p_nombre => 'BTN_AYUDA',
                          p_tipo => 'submit',
                          p_titulo=> '',
                          p_valor => 'ayuda',
                          p_desabilitado =>'N'));
       end if;
       add('</th>');
       add('   <th width="1" align="right">');
       if g_tabs.count > 0 then
          add(replace(boton(p_icono => 'arrow_back_ios_new',
                                  p_nombre => 'BTN_REGRESAR',
                                  p_tipo => 'submit',
                                  p_titulo=> '',
                                  p_valor => encrypt(g_pagina.id_maestro),
                                  p_desabilitado =>'N'),'>',' formnovalidate>'));
       else
          add('   <th width="1" align="right">');
          add('   <a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
       end if;
       add('   </th>');

       add('</tr>');
       add('</table>');
       add('</td>');
       add('</tr>');

       -- tabs de las paginas

       if g_tabs.count > 1  then
         add(tabs(p_column_count => 10));
       end if;

      -- filtros de las paginas
       if g_filtros.count > 0 then
          add ('<tr>');
          add ('<td colspan="'|| m_column_count||'">');
          add ('<table id="filtros">');
          for i in 1..g_filtros.count loop
            m_name := 'FILTRO_'||g_filtros(i).secuencia;
            if sesion_leer(g_id_sesion,g_pagina.id_pagina,m_name)  is not null then
               m_filtro_valor := sesion_leer(g_id_sesion,g_pagina.id_pagina,m_name);
               if (g_filtros(i).tipo_de_dato = 'CHK') then
                 m_filtro_valor :=  'S';
               end if;
               m_filtros := m_filtros+1;
            else
               m_filtro_valor :=  null;
            end if;
            add('<tr>');
            add('<td width="1"><span>'||g_filtros(i).titulo||':</span></td>');
            if (g_filtros(i).tipo_de_dato in('LOV','RAD')) then
                if (g_filtros(i).tipo_de_dato in('LOV')) then
                   m_lista_de_valores := m_lista_de_valores ||'$("#'||m_name||'").select2({width:''resolve''}); ';  -- antes decia element
                end if;
                m_control := lista_de_valores(p_nombre        => m_name,
                                                   p_lista_valores => g_filtros(i).lista_de_valores,
                                                   p_requerido     => 'N',
                                                   p_seleccionado  => m_filtro_valor,
                                                   p_deshabilitado => 'N',
                                                   p_tipo_dato     => g_filtros(i).tipo_de_dato,
                                                   p_autoposback   => g_filtros(i).autopostback);

                if (g_filtros(i).estilo is not null) then
                  m_control := substr(m_control,1,length(m_control)-1) || ' style="'||g_filtros(i).estilo||'">'  ;
                end if;
                add('<td width="*">'||m_control||'</td>');
            else
                m_control := trim(input_control(p_nombre => m_name,
                                          p_tipo => g_filtros(i).tipo_de_dato,
                                          p_requerido => 'N',
                                          p_placeholder => '',
                                          p_valor => m_filtro_valor,
                                          p_regexp_val => g_filtros(i).regexp_validacion,
                                          p_regexp_msg => g_filtros(i).regexp_mensaje,
                                          p_longitud => g_filtros(i).longitud,
                                          p_lista_de_valores => g_filtros(i).lista_de_valores)
                                          );
                if (g_filtros(i).estilo is not null) then
                  m_control := substr(m_control,1,instr(m_control,' ')-1)  -- antes del primer espacio
                            || ' style="'||g_filtros(i).estilo||'" '     -- poner el estilo
                            || substr(m_control,instr(m_control,' ')+1  );  -- despues del primer espacio
                end if;
                add('<td width="*">'||m_control||'</td>');
            end if;
            add('   </tr>');
          end loop;

          add('<tr><td colspan="2" align="right">');

          add(boton(p_icono => 'search',
                                      p_nombre => 'BTN_FILTRAR',
                                      p_tipo => 'submit',
                                      p_titulo=> 'Buscar',
                                      p_valor => 'Buscar',
                                      p_desabilitado => 'N' ));
          if (m_filtros>0) then
            add(boton(p_icono => 'mop',
                                        p_nombre => 'BTN_LIMPIAR',
                                        p_tipo => 'submit',
                                        p_titulo=> '',
                                        p_valor => 'Limpiar',
                                        p_desabilitado => 'N' ));
          end if;

          add('</td></tr>');
          add ('</table>');
          add('</td>');
          add ('</tr>');
       end if;
       add('</thead>');

       -- preparar query para consulta dinamica(que pueden venir una vista o un query)
       -- el elemento dinamico "g_pagina.consultar" viene de inv_db.man_paginas_t y no es input del usuario
       if (lower(g_pagina.consultar) like 'select %' or lower(g_pagina.consultar) like 'with %') then
          m_from_consulta := ' FROM ('||g_pagina.consultar||') a';
       else
          m_from_consulta := ' FROM '||g_pagina.consultar||' a';
       end if;

       -- los elementos dinamicos "g_pagina.campo_id" y "g_pagina.condicion_solo_lectura" vienen de inv_db.man_paginas_t y no son input del usuario
       m_consulta := 'SELECT '||g_pagina.campo_id ||' rid,'|| case when g_pagina.condicion_solo_lectura is not null then g_pagina.condicion_solo_lectura||' AS SOLO_LECTURA' else  '''N'' AS SOLO_LECTURA' end;

       for i in 1..g_columnas.count
       loop
          if (g_columnas(i).consultar='S') then /* RJ: para que el campo_id no venga 2 veces en el query si es un campo ID y a la vez editable como id_usuario*/
           if (g_columnas(i).tipo_de_dato='DOWN') then
             m_consulta := m_consulta||',null as '||g_columnas(i).columna;
           elsif  (g_columnas(i).expresion is null) then
             -- las columns dinamicas que se agregan vienen de inv_db.man_det_columnas_paginas_t y no son input del usuario
             m_consulta := m_consulta||','||g_columnas(i).columna;
           else
             -- las columns dinamicas que se agregan vienen de inv_db.man_det_columnas_paginas_t y no son input del usuario
             m_consulta := m_consulta||','||g_columnas(i).expresion||' as '||g_columnas(i).columna;
           end if;
           if g_formulario.exists('BTN_ORD_'||upper(g_columnas(i).columna)) then
              -- los elementos dinamicos "g_columnas(i).tipo_de_dato" y "g_columnas(i).columna" vienen de inv_db.man_det_columnas_paginas_t y no son input del usuario
              m_ordenar_por := case  when g_columnas(i).tipo_de_dato in('FEC','DEC','NUM')
                                     then 'a.'||g_columnas(i).columna         -- que saque la columna
                                     else g_columnas(i).columna end;

             if sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION') IS NOT NULL then
                 -- la direccion de sorteo dinamica viene de un boton que presiona el usuario, pero el valor que ponemos al query (asc o desc) no lo es
                 if (upper(g_columnas(i).columna)<> replace(sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO'),'a.','')) then
                    m_direccion := 'ASC';
                 else
                    if  sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION') = 'ASC'   then
                       m_direccion := 'DESC';
                    else
                       m_direccion := 'ASC';
                    end if;
                 end if;
              else
                m_direccion := 'ASC';
              end if;
           end if;
          end If;
       end loop;

       if (m_ordenar_por is null) then
         if (sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO') is not null) then
           m_ordenar_por := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO');
           m_direccion   := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION');
         elsif (g_pagina.ordenar_por is not null) then
           m_ordenar_por := g_pagina.ordenar_por;
           m_direccion   := nvl(g_pagina.ordenar_dir,'ASC');
         end if;
       end if;

       if m_ordenar_por is not null then
          add('<input type="hidden" name="ORD_CAMPO" value="'||m_ordenar_por||'" />');
          add('<input type="hidden" name="ORD_DIRECCION" value="'||m_direccion||'" />');
       end if;

       -- preparar la consulta dinamica que cuenta los registros
       m_consulta := m_consulta || m_from_consulta;
       m_consulta_count := 'SELECT count(*) '|| m_from_consulta;

       -- adicionando los where condicion que vienen desde filtros
       if sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO') is not null then
         -- los elementos dinamicos m_filtro_consulta y g_maestro.campo_id vienen de man_paginas_t y no son input del usuario
         m_filtro_consulta := ' WHERE '|| m_filtro_consulta||' '||g_maestro.campo_id||'=:ID_MAESTRO';
       end if;

       for i in 1..g_filtros.count loop
          -- los filtros son todos input del usuario
          m_name     := 'FILTRO_'||g_filtros(i).secuencia;
          m_name_val := sesion_leer(g_id_sesion,g_pagina.id_pagina,m_name);

          if (m_name_val IS NOT NULL) then
            if upper(nvl(m_filtro_consulta,'~')) not like '%WHERE%' then
              m_filtro_consulta := ' WHERE ';
            else
              m_filtro_consulta:= m_filtro_consulta || ' AND ';
            end if;

            if upper(g_filtros(i).condicion) = 'LIKE_U' then
              -- parametrizar like en mayusculas sin collate
              m_filtro_consulta := m_filtro_consulta||g_filtros(i).columna||' like :'||m_name;
            elsif upper(g_filtros(i).condicion) = 'LIKE' then
              -- parametrizar like con collate
              m_filtro_consulta:= m_filtro_consulta||g_filtros(i).columna||' like :'||m_name||' collate binary_ai';
            else
              m_filtro_consulta := m_filtro_consulta|| g_filtros(i).columna;
              if upper(g_filtros(i).tipo_de_dato) = 'FEC' then
                -- parametrizar fecha
                m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' to_date(:'||m_name||',''dd/mm/yyyy'')';
              else
                -- parametrizar cualquier otro tipo de dato
                m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' :'||m_name;
              end if;
            end if;
          end if;
       end loop;
       m_consulta := m_consulta||m_filtro_consulta;

       if m_filtro_consulta is null and g_pagina.id_maestro is not null   then
          -- el elemento dinamico "g_maestro.campo_id" viene de man_paginas_t y no es input del usuario
          m_consulta := m_consulta||' WHERE '|| g_maestro.campo_id||' = :ID_MAESTRO ';
       end if;

       m_consulta_count := m_consulta_count||m_filtro_consulta;

       -- el elemento dinamico "m_ordenar_por" y "m_direccion" viene de man_paginas_t y no son input del usuario
       m_consulta := m_consulta|| case when m_ordenar_por is not null then ' ORDER BY '||m_ordenar_por||' '||m_direccion end;

       if sesion_leer(g_id_sesion,g_pagina.id_pagina,'PAGINADOR') is not null then
         m_pagenum := sesion_leer(g_id_sesion,g_pagina.id_pagina,'PAGINADOR');
       else
         m_pagenum := 1;
       end if;

       m_registro_omitido := (m_pagesize *( m_pagenum - 1));
       m_consulta := m_consulta||' offset ' ||m_registro_omitido ||' rows fetch next '|| m_pagesize||' rows only ';

       --if sesion_leer(g_id_sesion,g_pagina.id_pagina,'TOTAL_REGISTROS') is not null then
       --  m_total_registro := sesion_leer(g_id_sesion,g_pagina.id_pagina,'TOTAL_REGISTROS');
       --else
            m_total_registro := ejecutar(m_consulta_count,'id_maestro',m_maestro_id);
         
       --  if (ceil(m_total_registro / m_pagesize) > 50) then
       --    -- si el conteo de paginas da mas de 50, guardalo en sesion para que no vuelvas a hacer ese mismo conteo
       --    sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'TOTAL_REGISTROS',m_total_registro);
       --  end if;
       --end if;

       add('<tbody>');
       -- encabezados de las columnas
       add('   <tr>');
       n:= 1;
       for i in 1..g_columnas.count loop
            if (g_columnas(i).consultar='S') then
                if g_columnas(i).alineacion = 'R'then
                   m_alineacion:= ' align="right"';
                elsif  g_columnas(i).alineacion = 'C'then
                   m_alineacion:= ' align="center"';
                else
                   m_alineacion:= '';
                end if;
               n := n +1;
               if(( n = 2 and (g_puede_borrar = 'S' or g_acciones.count > 0  or g_reportes_multi > 0 ))) then
                 add('<th width="1" class="scr'||g_columnas(i).visible_en||'" > &nbsp; </th>');
                 n := n +1;
                 m_headers := m_headers+1;
               end if;
               add('<th '||m_alineacion||' class="scr'||g_columnas(i).visible_en||'" '||case when m_colspan is not null then ' colspan="'||m_colspan||'" ' end||'>');
               if (g_columnas(i).tipo_de_dato in('HTML','MCHK','MULTI','PASS','CODE')) then
                 add(nvl(nvl(g_columnas(i).prefijo,g_columnas(i).sufijo),g_columnas(i).titulo));
               else
                 add('<input type="submit"'
                   ||' value="'||nvl(nvl(g_columnas(i).prefijo,g_columnas(i).sufijo),g_columnas(i).titulo)||'"'
                   ||' name="BTN_ORD_'||upper(g_columnas(i).columna)||'"'
                   || case
                      when upper(g_columnas(i).columna)=replace(upper(nvl(m_ordenar_por,'~')),'A.','') then ' class="sort_'||lower(m_direccion)||'"'
                      else ' class="sort_none"'
                      end
                   ||'>');
               end if;
               add('</th>');
               m_headers := m_headers+1;
            end if;
        end loop;

        if (n=m_column_count and g_puede_ver_tabs>0) then
          if (g_puede_ver_tabs=1) then
            -- este query crea el query dinamico t_tab_query, los elementos "mas.consultar" y "g_pagina.campo_id" vienen de man_paginas_t y no son input del usuario
            -- el id_registro es input de usuario y está parametrizado, el query dinamico t_tab_query se ejecuta mas adelante
              select tabs.plural, 'select count(*) from ('||mas.consultar||') where '||g_pagina.campo_id||'= :REC_ID'
              into t_tab_title, t_tab_query
              from inv_db.man_det_tabs_paginas_v tabs
              join inv_db.man_paginas_t mas on mas.id_pagina=tabs.id_pagina
              where tabs.id_usuario = g_id_usuario_procesa
              and tabs.id_maestro = g_pagina.id_pagina;

              add('<th align="center">'||replace(t_tab_title,' ','<br>')||'</th>');
          else
            add('<th width="1">Detalles</th>');
          end if;
          m_headers := m_headers+1;
        end if;
        add('     </tr>');

        if (m_total_registro=0) then
          -- no hay ningun registro, mostrar un mensaje
          for i in 1 .. (m_pagesize) loop
            add('<tr>');
            if (i=1) then
              add('<td rowspan="'||m_pagesize||'" colspan="'||m_headers||'" align="center">No se encontró ningún registro.</td>');
            end if;
            add('</tr>');
          end loop;

        else
         -- parsear la consulta para determinar los parametros que requiere
          dbms_sql.parse( l_theCursor, m_consulta, dbms_sql.native );
          pasar_parametros(l_theCursor, m_consulta,null,null);
          dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
          for i in 1 .. l_colCnt loop
            dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
          end loop;
          l_status := dbms_sql.execute(l_theCursor);

          -- esto es colo para quitar el l_status never used
          if (l_status is not null) then null; end if;
          -- iterar los registros que devuelve

          while(dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
            add('<tr>');
            for i in 3 .. l_colCnt loop -- empezamos en las 3 porque la columna  1,2 se puso manual
                l_columnName := l_descTbl(i).col_name;

                if columna(l_columnName).alineacion = 'R'then
                   m_alineacion:= ' align="right"';
                elsif columna(l_columnName).alineacion = 'C'then
                   m_alineacion:= ' align="center"';
                else
                   m_alineacion:= '';
                end if;
                
                if (columna(l_columnName).tipo_de_dato='DOWN') then
                  l_columnValue := null;
                  declare
                    x_cnt int;
                    x_sql varchar2(3200);
                  begin
                    x_sql := 'select count(*) from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:id and x.'||l_columnName||' is not null';
                    if (lower(x_sql) like '%:id_inventario%') then
                      execute immediate x_sql into x_cnt using g_id_inventario,l_campo_id_Value;
                    else
                      execute immediate x_sql into x_cnt using l_campo_id_Value;
                    end if;
                    
                    if (x_cnt<>0) then
                        x_sql := 'select '||l_columnName||'_filename from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:id';
                        if (lower(x_sql) like '%:id_inventario%') then
                          execute immediate x_sql into l_campo_id_Descrip using g_id_inventario,l_campo_id_Value;
                        else
                          execute immediate x_sql into l_campo_id_Descrip using l_campo_id_Value;
                        end if;
                        l_columnValue :=  boton(
                                          p_icono         => null,
                                          p_nombre        => 'BTN_DOWNLOAD',
                                          p_tipo          => 'submit',
                                          p_titulo        => 'Descargar',
                                          p_valor         => encrypt(
                                                              'id='||l_campo_id_Value           -- el id del registro actual
                                                             ||',field='||l_columnName          -- el campo a descargar
                                                             ||',filename='||l_campo_id_Descrip -- el campo que se usará como nombre del archivo
                                                             ||',ext='||null                    -- la extensión del archivo
                                                             ||',type='||null                   -- el content type del archivo
                                                             ),
                                          p_desabilitado  => 'N',
                                          p_estilo        => null,
                                          p_confirmacion  => null
                                        );
                    else
                      l_columnValue := null;
                    end if;
                  end;
                else
                  dbms_sql.column_value( l_theCursor, i, l_columnValue );
                end if;
                
                if (columna(l_columnName).tipo_de_dato not in ('HTML','CHK','DOWN')) then
                   l_columnValue := HTF.ESCAPE_SC(l_columnValue); -- No remover esta sentencia, es la que evita html Ijection
                end if;

                m_span_abre   := null;
                m_span_cierra := null;
                if columna(l_columnName).estilo_consultar is null then
                  m_estilo := '';
                else
                  if (columna(l_columnName).estilo_consultar like '%=%' and columna(l_columnName).estilo_consultar like '%,%') then
                    -- me estan pasando colores (background ó background/foreground) en formato A=green/white,I=yellow,B=red/white
                    m_estilo := '';
                    declare
                      m_colores varchar2(500);
                    begin
                      m_colores := columna(l_columnName).estilo_consultar;
                      if (m_colores like '%'||l_columnValue||'=%') then
                        -- si el valor existe en la lista, darle color
                        m_colores := substr(m_colores,instr(m_colores,l_columnValue||'=')+length(l_columnValue)+1);
                        if (m_colores like '%,%') then
                          m_colores := substr(m_colores,1,instr(m_colores,',')-1);
                        end if;
                        if (m_colores like '%/%') then
                          -- son dos colores (background/foreground)
                          m_span_abre := '<span style="border-radius:3px; padding: 3px; background-color:'||substr(m_colores,1,instr(m_colores,'/')-1)||'; color:'||substr(m_colores,instr(m_colores,'/')+1)||';">';
                        else
                          m_span_abre := '<span style="border-radius:3px; padding: 3px; background-color:'||m_colores||';">';
                        end if;
                        m_span_cierra := '</span>';
                      end if;
                    end;
                  else
                    m_estilo := ' style="'||  columna(l_columnName).estilo_consultar||'"';
                  end if;
                end if;

                if (i = 3) then
                  -- si es la tercera co
                   dbms_sql.column_value(l_theCursor,1, l_campo_id_Value);
                   dbms_sql.column_value(l_theCursor,2, m_cond_solo_lectura);
                   if (g_puede_borrar = 'S' or g_acciones.count > 0 or g_reportes_multi > 0) then
                      if g_puede_borrar = 'S' then
                         m_boton_borrar:='<button type="submit" value="BORRAR" name="BTN_BORRAR" onclick="return checkboxes_seleccionados(''¿Seguro que desea borrar el registro seleccionado?'',''¿Seguro que desea borrar los registros seleccionados?'');"><img src="/_images/delete.png" /><span class="btn_label">Borrar</span></button>';
                      end if;
                        l_campo_id_ValueEnc := encrypt(l_campo_id_Value);
                        m_check_borrar:=' <td width="1"><input type = "checkbox" name="CHK_REGISTRO_'||l_campo_id_ValueEnc||'"></td>';
                        m_check_count := m_check_count+1;
                   else
                      m_boton_borrar:='';
                      m_check_borrar:='';
                   end if;

                   l_campo_id_ValueEnc := encrypt(l_campo_id_Value);
                  add(m_check_borrar||' <td'||m_alineacion||m_estilo||'>'||'<input type="submit" value="'||l_columnValue||'" name="LINK_VER_'||l_campo_id_ValueEnc||'">'||'</td>');
                else
                   if i = l_colCnt and g_puede_ver_tabs>0 then
                     l_campo_id_ValueEnc := encrypt(l_campo_id_Value);
                     if (g_puede_ver_tabs=1) then
                       t_tab_number := ejecutar(t_tab_query,'REC_ID',l_campo_id_Value);
                       m_boton_detalle:=' <td align="center"><button type="submit" name="BTN_DET_'||l_campo_id_ValueEnc||'">'||t_tab_number||'</button></td>';
                     else
                       m_boton_detalle:=' <td align="center"><button type="submit" name="BTN_DET_'||l_campo_id_ValueEnc||'"><img src="/_images/more_horiz.png" /></button></td>';
                     end if;
                   end if;

                   if (columna(l_columnName).tipo_de_dato='ICON') then
                      l_columnValue := '<img src="/_images/'||l_columnValue||'.png" />';
                   end if;

                   if (columna(l_columnName).tipo_de_dato='CHK') then
                     if (l_columnValue='S') then
                       l_columnValue := '&#10003;';
                     elsif (l_columnValue='N') then
                       l_columnValue := '&#10007;';
                     else
                       l_columnValue := '&sdot;';
                     end if;
                   end if;

                   add(' <td class="scr'||columna(l_columnName).visible_en||'" '||m_alineacion||m_estilo||'>'||m_span_abre||l_columnValue||m_span_cierra||'</td>');
                end if;
            end loop;
            if g_puede_ver_tabs>0 then
              add(m_boton_detalle);
            end if;
            add('</tr>');
            m_cant_registro := m_cant_registro + 1;
         end loop;
       end if;
      -- guardar en sesion la cantidad de registros en pantalla, por si borran alguno saber en que pagina quedarnos
      sesion_guardar(g_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'CANT_REGISTROS',m_cant_registro);

      dbms_sql.close_cursor(l_theCursor);

      if (m_total_registro>0 and m_cant_registro < m_pagesize) then
       -- hay por lo menos un registro, imprimir lineas vacias restantes hasta el tama`no de pagina
       for i in 1 .. (m_pagesize - m_cant_registro) loop
        add('   <tr>');
        n:= 1;
        for i in 1..g_columnas.count loop
            if (g_columnas(i).consultar='S') then
               n := n +1;
               if(( n = 2 and g_puede_borrar = 'S' )) then
                add('<td class="scr'||g_columnas(i).visible_en||'">&nbsp;</td>');
               end if;
               add('<td class="scr'||g_columnas(i).visible_en||'">&nbsp;</td>');
               if (n = m_column_count -1 and g_puede_ver_tabs>0) then
                 add('<td>&nbsp;</td>');
               end if;
            end if;
         end loop;
        end loop;
        add('   </tr>');
       end if;

       -- footer para botones y paginadort
      add('</tbody>');
      add('<tfoot>');
      add('<tr>');
      add('<td colspan="'||(m_column_count)||'">');
      add('<table>');
      add('<tr>');
      if g_pagina.imprimir = 'S' then
         m_boton_imprimir:='<button type="submit" value="IMPRIMIR" name="BTN_IMPRIMIR"><img src="/_images/print.png" /><span class="btn_label">Imprimir</span></button>';
         if (m_total_registro >= 2000) then
             m_boton_imprimir := replace(m_boton_imprimir,'<button','<button onclick="return prompt(''Esta acción va a imprimir '||m_total_registro||' registros y podría tardarse unos minutos, para continuar escriba dicho número:'')==='''||m_total_registro||''';"');
         end if;
      end if;

      if g_pagina.descargar = 'S' then
         m_boton_excel:='<button type="submit" value="EXPORTAR" name="BTN_EXPORTAR"><img src="/_images/download.png" /><span class="btn_label">Exportar</span></button>';
         if (m_total_registro >= 2000) then
           m_boton_excel := replace(m_boton_excel,'<button','<button onclick="return prompt(''Esta acción va a exportar '||m_total_registro||' registros y podría tardarse unos minutos, para continuar escriba dicho número:'')==='''||m_total_registro||''';"');
         end if;
      end if;

      if (g_puede_agregar='S') then
        m_boton_agregar:='<button type="submit" value="AGREGAR" name="BTN_AGREGAR"><img src="/_images/add_circle.png" /><span class="btn_label">Agregar</span></button>';
      else
        m_boton_agregar:=' ';
      end if;

      add(' <td width="*" id="foot_acciones">');

      -- si hay por lo menos un checkbox renderiza el boton de borrar
      if (m_check_count>0) then
        add(m_boton_borrar);
      end if;

      -- si la condicion del maestro es de solo lectura, no renderizar al boton agregar
--      if (g_pagina.condicion_solo_lectura is not null) then
      if (g_maestro.condicion_solo_lectura is not null) then
        declare
          m_sql varchar2(4000);
        begin
          -- los elementos dinamicos "g_pagina.condicion_solo_lectura", "g_maestro.consultar" y "g_maestro.campo_id" vienen de man_paginas_t y no son input del usuario
          -- el m_id es input del usuario y está parametrizado
          m_sql := 'select '||g_maestro.condicion_solo_lectura||' as condicion from ('||g_maestro.consultar||') where '||g_maestro.campo_id||'=:M_MAS_ID';
          m_cond_solo_lectura := ejecutar(m_sql,'M_MAS_ID',m_maestro_id);
        exception when others then
          m_cond_solo_lectura := 'N';
        end;
      else
        m_cond_solo_lectura := 'N';
      end if;
      if (m_cond_solo_lectura='N') then
        add(m_boton_agregar);
      end if;
      -- si hay por lo menos un checkbox renderiza los botones de acciones
      if (m_check_count>0) then
        --- Acciones de las paginas
         if g_acciones.count > 0 then
            for i in 1 .. g_acciones.count loop
                add(boton(p_icono => g_acciones(i).icono,
                                p_nombre => 'BTN_ACCION_'||g_acciones(i).id_accion,
                                p_tipo => 'submit',
                                p_titulo=> g_acciones(i).accion,
                                p_valor => g_acciones(i).id_accion,
                                p_desabilitado => 'N',
                                p_confirmacion => case
                                                  when g_acciones(i).confirmacion_singular is not null or g_acciones(i).confirmacion_plural is not null
                                                  then ' onclick="return checkboxes_seleccionados('''||g_acciones(i).confirmacion_singular||''','''||g_acciones(i).confirmacion_plural||''');"'
                                                  else ''
                                                  end
                                )
                    );
            end loop;
         end if;

         --- Reportes de las paginas
         if g_reportes_multi > 0 then
            for i in 1 .. g_reportes.count loop
              if (g_reportes(i).seleccion_multiple='S') then
                add(boton(p_icono =>  'print',
                             p_nombre => 'BTN_REPORTE_'|| encrypt(g_reportes(i).id_reporte),
                             p_tipo =>   'submit',
                             p_titulo=>   g_reportes(i).reporte,
                             p_valor =>   encrypt(g_reportes(i).id_reporte),
                             p_desabilitado => 'N',
                             p_confirmacion => ' onclick="return checkboxes_seleccionados(''¿Seguro que desea imprimir el registro seleccionado?'',''¿Seguro que desea imprimir los registros seleccionados?'');"'));

              end if;
            end loop;
         end if;
       end if;

       ---------------------------------------------------------
       if m_total_registro > 0 then
          m_pagetotal := ceil(m_total_registro / m_pagesize);
          add(m_boton_imprimir);
          add(m_boton_excel);
       else
          m_pagetotal := 1;
       end if;

       if (g_pagina.autorefrescar is not null) then
         declare
           m_segundos varchar2(2) := g_pagina.autorefrescar;
         begin
           if (g_formulario.exists('TXT_AUTOREFRESH')) then
             m_segundos := g_formulario('TXT_AUTOREFRESH');
           end if;
           if (m_segundos<g_pagina.autorefrescar) then
             m_segundos := g_pagina.autorefrescar;
           end if;
           add('Auto-refresh <input type="number" id="TXT_AUTOREFRESH" name="TXT_AUTOREFRESH" min="'||g_pagina.autorefrescar||'" max="900" style="width:32px;" value="'||m_segundos||'"> segs. '
             ||'<img id="ar" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAASRJREFUOI1jYEADjEwsLMapyzZ5Tnj3H4TR5fECk/RV28Aa+9/+U/WqauaXMzIlWrNL6903IM28Utp6+NQpuxRWQlz39p+4nncgis2MTMzMBC1qv/8e5j0pk7AYsJ+JsRkGQGrF9XwCQTQLBy8fAzjAgH4myp9IwKP/zV+z7I37wCYCA6yJVANUPMrrwbEEIvjlDIkPbSgAxRDCAFlDEzIMMIMboOJeVkeqAWpe1S1gA8xzNu0HBQipBoDSgVHK0o0MLBx8/JCo8Q0mNunySesYQNMNC4O0aUQcLGG4tN17R0gzSBNIrUnaii1gAXFd70BQOgAJKjnnl+O3WRdss3PrnddE+RMEBOSNzdS8QQEGscQkbeVWojWDAMx7xsAAAyV7dHkA1TGeDohzCg0AAAAASUVORK5CYII=">'
             ||'<script>'
             ||' var auto_refresh = setInterval('
             ||' function() {submitform(); },'||m_segundos||'000);'
             ||' function submitform() {'
             ||'  document.forms[0].submit();'
             ||' }'
             ||'</script>'
           );
         end;
       end if;

       add('</td>'); -- cierre del td del footer de los botones de accion

       if (m_pagetotal>1) then
         add('<td width="1">'||boton('keyboard_double_arrow_left' ,'PAGINA_PRIMERA' ,'submit','','1'           ,case when m_pagenum=1 then 'S' else '' end)||'</td>');
         add('<td width="1">'||boton('navigate_before'            ,'PAGINA_ANTERIOR','submit','',(case when m_pagenum<=1 then 1 else m_pagenum-1 end),case when m_pagenum=1 then 'S' else '' end)||'</td>');

         if m_pagetotal <= 50 then
            m_consulta_lista:= 'select rownum pag,rownum||'' de ''||'||m_pagetotal||' from dual connect by rownum<='||m_pagetotal;
            add('<td width="1">'||replace(lista_de_valores('PAGINADOR',m_consulta_lista,'-',m_pagenum,case when m_pagetotal=1 then 'S' else 'N' end,'LOV','S'),'<select ','<select ')||'</td>');
         else
            add('<td width="1"><input type="number" step="1" maxlength="'||length(trim(to_char(m_pagetotal)))||'" min="1" max="'||m_pagetotal||'" id="PAGINADOR" name="PAGINADOR" value="'||m_pagenum||'"></td>');
            add('<td width="1" class="scrM">&nbsp;de&nbsp;'||m_pagetotal||'</td>');
         end if;

         add('<td width="1">'||boton('navigate_next'              ,'PAGINA_SIGUIENTE','submit','',(case when m_pagenum>=m_pagetotal then m_pagetotal else m_pagenum+1 end),case when m_pagenum=m_pagetotal then 'S' else '' end));
         add('<td width="1">'||boton('keyboard_double_arrow_right','PAGINA_ULTIMA'   ,'submit','',m_pagetotal   ,case when m_pagenum=m_pagetotal then 'S' else '' end)||'</td>');
      end if;


    add('</tr>');
    add('</table>');
    add('</td>');
    add('</tr>');
    add(' </tfoot>');
    add('</table>');

    add(' <script language="javascript">');
    add('   jQuery.noConflict();');
    add('   jQuery(document).ready(function($) {');
    add(m_lista_de_valores);
    if (g_resultado like '%class="fecha"%') then
      add('    $(".fecha").datepicker({
                onSelect: function(date) {document.forms["mainForm"].submit();},
                dateFormat: "dd/mm/yy",
                dayNamesMin: [ "Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sa" ],
                dayNamesShort: [ "Dom", "Lun", "Mar", "Mie", "Jue", "Vie", "Sab" ],
                monthNames: [ "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                });');
    end if;
    add('  });');
    add('');
    if (g_resultado like '%checkboxes_seleccionados%') then
      add('function checkboxes_seleccionados(singular,plural){');
      add('  var inputElems = document.getElementsByTagName("input"),');
      add('  count = 0;');
      add('  for (var i=0; i<inputElems.length; i++) {');
      add('    if (inputElems[i].type === "checkbox" && inputElems[i].checked === true){');
      add('        count++;');
      add('    }');
      add('  }');
      add('  if (count==0) {');
      add('    swal({text:"Debe seleccionar al menos un registro.",icon:"warning",});');
      add('    return false;');
      add('  } else if (count==1) {');
      add('    return confirm(singular);');
      add('  } else {');
      add('    return confirm(plural);');
      add('  }');
      add('}');
    end if;
    if (g_pagina.javascript is not null) then
      add(g_pagina.javascript);
    end if;
    add(' </script>');
  end consultar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar un gráfico de barras, lineas o pastel utilizando la libreria google chart-api
                 esto funciona ejecutando la sentencia sql en el campo "consultar" de la pagina actual
                 dependiente del tipo, debe devolver 2 (pastel o barras),3 (lineas) o 4 columnas (si es lineas y es un detalle de otra página)
                 con los valores de esas columnas se invoka al google chart api, pasandole los valores y una paleta de colores
  */
  procedure graficar is
    c sys_refcursor;
    TYPE t_columnas IS TABLE OF varchar2(500);
    TYPE t_valores  IS TABLE OF number(24,6);
    tmp_clob  clob;
    grafica_clob  clob;
    a_columna_1 t_columnas;
    a_columna_2 t_columnas;
    a_valores   t_valores;

    d_columna_1 t_columnas;
    d_columna_2 t_columnas;

    m_valor   varchar2(100);
    m_label   clob;
    m_data    clob;
    m_colores clob;

    m_maestro_id varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');

    m_suma_valor number :=0;
    m_consulta varchar2(1000);
    m_consulta_lista   varchar2(4000);
    m_lista_de_valores varchar2(4000) := null;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : devolver un string que contiene la paleta de colores que se utilizará para rendizar el gráfico
      * @p_cantidad: cantidad de colores a devolver (un color para cadea registro que devuelva la sentencia del campo "consultar"
      *              antes era random, pero obteniamos demaciados colores similares, se cambió a una lista de 140 colores agradables fijos,
      *              a partir de ahi serán ramdom
    */
    function colores(
      p_cantidad in number
    )
    return varchar2 is
      res varchar2(4000);
      n int := 1;
      r int;
      g int;
      b int;
      fixed_colors varchar2(4000) := '"#0000FF","#00FFFF","#FF69B4","#D8BFD8","#6B8E23","#FA8072","#FFB6C1","#000080","#FF00FF","#808080","#F08080","#F5DEB3","#7FFFD4","#FF0000","#D2691E","#CD5C5C","#FF00FF","#FF4500","#228B22","#66CDAA","#1E90FF","#808080","#EEE8AA","#008080","#F0FFF0","#FFE4B5","#FFFAF0","#EE82EE","#40E0D0","#708090","#0000CD","#483D8B","#4682B4","#D2B48C","#FFC0CB","#8A2BE2","#7B68EE","#9370DB","#9932CC","#A52A2A","#B0E0E6","#D3D3D3","#20B2AA","#556B2F","#BA55D3","#C71585","#ADD8E6","#006400","#00CED1","#FFEFD5","#696969","#FFF8DC","#008B8B","#FF8C00","#B0C4DE","#00FFFF","#E0FFFF","#DEB887","#FFD700","#FFDAB9","#708090","#8B0000","#778899","#8FBC8F","#696969","#7CFC00","#3CB371","#7FFF00","#FFE4C4","#778899","#87CEFA","#F5F5F5","#808000","#E6E6FA","#8B4513","#AFEEEE","#A0522D","#2E8B57","#008000","#4169E1","#00BFFF","#4B0082","#B8860B","#E9967A","#FFE4E1","#FFFACD","#B22222","#FF6347","#8B008B","#DCDCDC","#A9A9A9","#DA70D6","#5F9EA0","#FF1493","#90EE90","#DC143C","#FF7F50","#F4A460","#BDB76B","#98FB98","#C0C0C0","#DB7093","#9400D3","#FAFAD2","#6495ED","#800080","#BC8F8F","#00008B","#FAF0E6","#00FA9A","#87CEEB","#FDF5E6","#191970","#FFFFE0","#663399","#A9A9A9","#800000","#2F4F4F","#DAA520","#FFA500","#FFF5EE","#FFA07A","#00FF00","#6A5ACD","#D3D3D3","#CD853F","#00FF7F","#DDA0DD","#FFFF00","#2F4F4F","#000000","#32CD32","#FFF0F5","#48D1CC","#FAEBD7","#F0F8FF","#ADFF2F","#F0E68C","#F5F5DC","#FFEBCD",';
    begin
      if (p_cantidad<=140) then
        res := substr(fixed_colors,1,(p_cantidad*10)-1);
      else
        n := 140;
        --add random colors
        while (n <= p_cantidad) loop
          r := round(dbms_random.value(0,255)); --0-255
          g := round(dbms_random.value(0,255));
          b := round(dbms_random.value(0,255));
          res := res||'"rgba('||r||','||g||','||b||',0.5)"';
          if (n<p_cantidad) then
            res := res||',';
          end if;
          n := n+1;
        end loop;
      end if;
      if (p_cantidad>1) then
        res := '['||res||']';
      end if;

      return res;
    end colores;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : renderizar un gráfico de barras o pastel
    */
    procedure bar_pie is
    begin
      open c for m_consulta;
      FETCH c BULK COLLECT INTO a_columna_1, a_valores;

      if (a_columna_1.count>0) then
        -- determinar si el eje x con fechas para formatearlas dd/mm/yyyy
        declare
          m_tmp_date date;
        begin
          m_tmp_date := to_date(a_columna_1(1)); --ignore este warning: es para que de error si no es una fecha válida
          -- si está aqui  es una fecha, formatearlas todas
          FOR i IN 1 .. a_columna_1.count
          LOOP
            a_columna_1(i) := to_char(to_date(a_columna_1(i)),'dd/mm/yyyy'); -- ignore este warning: es para que de error si no es una fecha válida
          end loop;
        exception when others then
          -- aceptar que dió error por que no es una fecha
          null;
        end;
      end if;

      d_columna_1 := a_columna_1;
      d_columna_1 := d_columna_1 MULTISET INTERSECT DISTINCT d_columna_1;

      -- labels
      FOR i IN 1 .. d_columna_1.count
      LOOP
        m_label := m_label||'"'||d_columna_1(i)||'"'||case when i<d_columna_1.count then ',' else '' end;
      end loop;
       grafica_clob:=grafica_clob||'    labels: ['||m_label||'],'||chr(13);

      -- data
      grafica_clob:=grafica_clob||'    datasets: ['||chr(13);
      grafica_clob:=grafica_clob||'      {'||chr(13);
      for x in 1..d_columna_1.count loop
          m_suma_valor := 0;
          m_suma_valor := a_valores(x);
          m_data := m_data||m_suma_valor||case when x < d_columna_1.count then ',' else '' end;
      end loop;
      m_colores := colores(d_columna_1.count);
      grafica_clob:=grafica_clob||'        data: ['||m_data||'],'||chr(13);
      grafica_clob:=grafica_clob||'        backgroundColor: '||m_colores||','||chr(13);
      grafica_clob:=grafica_clob||'        borderColor: '||replace(m_colores,',0.5','')||','||chr(13);
      grafica_clob:=grafica_clob||'        borderWidth: 1,'||chr(13);
      grafica_clob:=grafica_clob||'        fill: false'||chr(13);
      grafica_clob:=grafica_clob||'      }'||chr(13);
    end bar_pie;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : Renderizar un gráfico de líneas
    */
    procedure line is
      m_color varchar2(32000);
    begin
      open c for m_consulta;
      FETCH c BULK COLLECT INTO a_columna_1, a_columna_2, a_valores;

      -- determinar si el eje x son fechas para formatearlas dd/mm/yyyy
      if (a_columna_2.count>0) then
        declare
          m_tmp_date date;
        begin
          m_tmp_date := to_date(a_columna_2(1)); -- ignore este warning: es ara ver si es una fecha válida
          -- si está aqui es una fecha, formatearlas todas
          FOR i IN 1 .. a_columna_2.count
          LOOP
            a_columna_2(i) := to_char(to_date(a_columna_2(i)),'dd/mm/yyyy'); -- ignore este warning: es para ver que sea una fecha válida
          end loop;
        exception when others then
          -- aceptar que dió error por que no es una fecha
          null;
        end;
      end if;

      d_columna_1 := a_columna_1;
      d_columna_1 := d_columna_1 MULTISET INTERSECT DISTINCT d_columna_1;

      d_columna_2 := a_columna_2;
      d_columna_2 := d_columna_2 MULTISET INTERSECT DISTINCT d_columna_2;

      -- labels
      FOR i IN 1 .. d_columna_2.count
      LOOP
         m_label := m_label ||'"'||d_columna_2(i)||'"'||case when i<d_columna_2.count then ',' else '' end;
      end loop;
      grafica_clob:=grafica_clob||'    labels: ['||m_label||'],'||chr(13);

      -- data
      grafica_clob:=grafica_clob||'    datasets: ['||chr(13);
      m_colores := colores(d_columna_1.count);
      m_colores := replace(replace(m_colores,'[',''),']','');
      for x in 1..d_columna_1.count loop
          grafica_clob:=grafica_clob||'      {'||chr(13);
          m_color := substr(m_colores,((x-1)*10)+1,9);
          m_data:= '';
          for y in 1..d_columna_2.count loop
              m_valor := 'undefined';
              for z in 1..a_valores.count loop
                 if (a_columna_1(z)= d_columna_1(x) and a_columna_2(z)= d_columna_2(y)) then
                    m_valor := a_valores(z);
                    exit;
                 end if;
              end loop;
              m_data := m_data||m_valor||case when y < d_columna_2.count then ',' else '' end;
         end loop;
         grafica_clob:=grafica_clob||'        data: ['||m_data||'],'||chr(13);
         grafica_clob:=grafica_clob||'        label: "'||d_columna_1(x)||'",'||chr(13);
         grafica_clob:=grafica_clob||'        borderColor: '||m_color||','||chr(13);
         grafica_clob:=grafica_clob||'        backgroundColor: '||m_color||','||chr(13);
         grafica_clob:=grafica_clob||'        fill: false'||chr(13);
         grafica_clob:=grafica_clob||'      }'||case when x < d_columna_1.count then ',' else '' end||chr(13);
      end loop;
    end line;
  -------------------------------------------------------------------------------
  begin
     add('<table id="ventana" class="graficar">');
     add('<thead>');

     add('<tr>');
     add('<td>');

     add('<table>');
     add('<tr>');
     add('<th width="*" id="consultar_titulo" >');
     if g_pagina.id_maestro is null then
         add(g_pagina.titulo);
     else
          if g_tabs.count > 0 then
             add(g_maestro.singular);
          else
             add(g_pagina.plural||' de ' ||g_maestro.singular);
         end if ;
         m_consulta_lista:= 'select '|| g_maestro.campo_id||','|| g_maestro.campo_descripcion ||' FROM '||g_maestro.consultar||' ORDER BY '||g_maestro.campo_descripcion;
         m_lista_de_valores := m_lista_de_valores ||'$("#LOV_MAESTRO").select2('||g_select2_params||'); ';
         tmp_clob := lista_de_valores(p_nombre        => 'LOV_MAESTRO',
                                            p_lista_valores => m_consulta_lista,
                                            p_requerido     => '-',
                                            p_seleccionado  => m_maestro_id,
                                            p_deshabilitado => 'N',
                                            p_tipo_dato     => 'LOV',
                                            p_autoposback   => 'S');
          add(tmp_clob);
     end if;
     add('</th>');

     if (m_maestro_id is null) then
         tmp_clob     := substr(tmp_clob, instr(tmp_clob,'<option value="')+15);
         m_maestro_id := substr(tmp_clob, 1, instr(tmp_clob,'"')-1);
     end if;

     add('   <td width="1">');
     if g_pagina.documentacion is not null then
        add(boton(p_icono => 'help_center',
                        p_nombre => 'BTN_AYUDA',
                        p_tipo => 'submit',
                        p_titulo=> '',
                        p_valor => 'ayuda',
                        p_desabilitado =>'N'));
     end if;
     add('</td>');

     if g_tabs.count > 0 then
        add('   <td width="1" align="right">');
        add(replace(boton(p_icono => 'arrow_back_ios_new',
                                p_nombre => 'BTN_REGRESAR',
                                p_tipo => 'submit',
                                p_titulo=> '',
                                p_valor => encrypt(g_pagina.id_maestro),
                                p_desabilitado =>'N'),'>',' formnovalidate>'));
        add('</td>');
     else
        add('   <td width="1" align="right">');
        add('   <a href="/Bienvenida.aspx"><img src="/_images/close.png" /></a>');
        add('   </td>');
     end if;

     add('</tr></table>');
     add('</td></tr>');

    -- tabs de las paginas
    if g_tabs.count > 0 then
       add(tabs(50));
    end if;

    add('</thead>');
    add('<tbody>');
    add('<tr>');
    add('<td>');

    --preparar query para consulta dinamica(que puden venir una vista o un query)
    if (lower(g_pagina.consultar) like 'select %' or lower(g_pagina.consultar) like 'with %') then
       m_consulta := g_pagina.consultar;
    else
      m_consulta := null;
      for cols in (
        select column_name col
        from all_tab_columns atc
        where owner||'.'||table_name = upper(g_pagina.consultar)
        and column_name <> upper(g_pagina.campo_id)
        order by column_id
      ) loop
        m_consulta := m_consulta||case when m_consulta is null then 'select ' else ',' end||cols.col;
      end loop;
       m_consulta := m_consulta||' FROM '||g_pagina.consultar;
    end if;

    if (lower(g_pagina.consultar) not like '%where%') then
       if g_pagina.id_maestro is not null then
          m_consulta := m_consulta||' WHERE '|| g_pagina.Campo_Id ||' = ''' ||m_maestro_id||'''';
       end if;
    else
       if g_pagina.id_maestro is not null then
          m_consulta := m_consulta||' AND '|| g_pagina.Campo_Id ||' = ''' ||m_maestro_id||'''';
       end if;
    end if;

    if (lower(g_pagina.consultar) not like '%order by %') then
      m_consulta := m_consulta ||case when g_pagina.ordenar_por is not null then ' ORDER BY '||g_pagina.ordenar_por end||' '||g_pagina.ordenar_dir;
    end if;

    -- codigo constante inicial
    grafica_clob:='<div id="chart-container">'||chr(13);
    grafica_clob:=grafica_clob||' <canvas id="chart" style="width:100%; height:100%;"></canvas>'||chr(13);
    grafica_clob:=grafica_clob||'</div>'||chr(13);
    grafica_clob:=grafica_clob||'<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.5.0/Chart.min.js"></script>'||chr(13);
    grafica_clob:=grafica_clob||'<script>'||chr(13);
    grafica_clob:=grafica_clob||'new Chart(document.getElementById("chart"), {'||chr(13);
    grafica_clob:=grafica_clob||'type: '''||case g_pagina.tipo when 'B' then 'bar' when 'P' then 'pie' when 'L' then 'line' end||''','||chr(13); --- if
    grafica_clob:=grafica_clob||'data: {'||chr(13);

    ----------------------------------------------------------------------

    if (g_pagina.tipo = 'B' or g_pagina.tipo = 'P') then
        bar_pie();
    else
        line();
    end if;

    -- codigo constante final
    grafica_clob:=grafica_clob||'    ]'||chr(13);
    grafica_clob:=grafica_clob||'  },'||chr(13);
    grafica_clob:=grafica_clob||'  options: {'||chr(13);
    grafica_clob:=grafica_clob||'    title: {display: false,},'||chr(13);
    grafica_clob:=grafica_clob||'    responsive: true,'||chr(13);
    grafica_clob:=grafica_clob||'    maintainAspectRatio: false,'||chr(13);

    if ((upper(g_pagina.tipo) = 'B') OR (upper(g_pagina.tipo) = 'L' and d_columna_1.count = 1))  then
         grafica_clob:=grafica_clob||'    legend: {display: false},'||chr(13);
    end if;

    if (upper(g_pagina.tipo) = 'B' or upper(g_pagina.tipo) = 'L') then
        grafica_clob:=grafica_clob||'    scales: { yAxes: [{ ticks: { beginAtZero: true  }}]}'||chr(13);
    end if;

    if (upper(g_pagina.tipo)='P') then
         grafica_clob:=grafica_clob||'    tooltips: {'||chr(13);
         grafica_clob:=grafica_clob||'      callbacks: {'||chr(13);
         grafica_clob:=grafica_clob||'        label: function(tooltipItem, data) {'||chr(13);
         grafica_clob:=grafica_clob||'          var datasetLabel = '''';'||chr(13);
         grafica_clob:=grafica_clob||'          var label = data.labels[tooltipItem.index];'||chr(13);
         grafica_clob:=grafica_clob||'          return (data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, ''$&,'');'||chr(13);
         grafica_clob:=grafica_clob||'        }'||chr(13);
         grafica_clob:=grafica_clob||'      }'||chr(13);
         grafica_clob:=grafica_clob||'    }'||chr(13);
    end if;

    grafica_clob:=grafica_clob||'      }'||chr(13);
    grafica_clob:=grafica_clob||'      });'||chr(13);
    grafica_clob:=grafica_clob||'  </script>'||chr(13);

    if d_columna_1.count = 0 then
      add('<div id="chart-container"> <b>No hay datos para graficar.</b></div>');
    else
      add(grafica_clob);
    end if;

    add('   </td>' );
    add('</tr>');
    add('</tbody>');

    if (g_pagina.autorefrescar is not null) then
      add('<tr><td>');
      declare
        m_segundos varchar2(2) := g_pagina.autorefrescar;
      begin
        if (g_formulario.exists('TXT_AUTOREFRESH')) then
          m_segundos := g_formulario('TXT_AUTOREFRESH');
        end if;
        if (m_segundos<g_pagina.autorefrescar) then
          m_segundos := g_pagina.autorefrescar;
        end if;
        add('Auto-refresh <input type="number" id="TXT_AUTOREFRESH" name="TXT_AUTOREFRESH" min="'||g_pagina.autorefrescar||'" max="900" style="width:32px;" value="'||m_segundos||'"> segs. '
          ||'<img id="ar" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAASRJREFUOI1jYEADjEwsLMapyzZ5Tnj3H4TR5fECk/RV28Aa+9/+U/WqauaXMzIlWrNL6903IM28Utp6+NQpuxRWQlz39p+4nncgis2MTMzMBC1qv/8e5j0pk7AYsJ+JsRkGQGrF9XwCQTQLBy8fAzjAgH4myp9IwKP/zV+z7I37wCYCA6yJVANUPMrrwbEEIvjlDIkPbSgAxRDCAFlDEzIMMIMboOJeVkeqAWpe1S1gA8xzNu0HBQipBoDSgVHK0o0MLBx8/JCo8Q0mNunySesYQNMNC4O0aUQcLGG4tN17R0gzSBNIrUnaii1gAXFd70BQOgAJKjnnl+O3WRdss3PrnddE+RMEBOSNzdS8QQEGscQkbeVWojWDAMx7xsAAAyV7dHkA1TGeDohzCg0AAAAASUVORK5CYII=">'
          ||'<script>'
          ||' var auto_refresh = setInterval('
          ||' function() {submitform(); },'||m_segundos||'000);'
          ||' function submitform() {'
          ||'  document.forms[0].submit();'
          ||' }'
          ||'</script>'
        );
      end;
      add('</td></tr>');
    end if;

    add('</table>');

    add(' <script language="javascript">');
    add('   jQuery.noConflict();');
    add('   jQuery(document).ready(function($) {');
    add(m_lista_de_valores);
    add('  });');
    add(' </script>');

  end graficar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderizar una página de ayuda para la página actual
    *            dicha ayuda se encuentra en formato txt o html en el campo documentacion de la tabla man_paginas_t, para el id de la pagina actual
  */
  procedure ayuda is
  begin
    log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Ver ayuda');
    
    add('<table id="ventana">');
    add(' <thead>');
    -- titulo de la pagina
    add('  <tr>');
    add('   <th width="*" id="consultar_titulo">'||g_pagina.titulo||'</th>');
    add('   <th width="1" align="right">');
    add(boton(p_icono => 'arrow_back_ios_new',
                    p_nombre => 'BTN_VOLVER',
                    p_tipo => 'submit',
                    p_titulo=> '',
                    p_valor =>  man_mantenimientos_pkg.encrypt(g_pagina.id_pagina),
                    p_desabilitado =>'N'));
    add('</th>');

    add('   </tr>');
    add(' </thead>');
    add(' <tbody>');
    add('<tr>');
    add('<td colspan="2" style="margin:15px; padding:15px; white-space: pre-line;">');
    add(g_pagina.documentacion);
    add('</td>');
    add('</tr>');
    add(' </tbody>');
    -- footer para botones y paginadort
    add(' <tfoot>');
    add(' </tfoot>');
    add('</table>');
  end ayuda;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : renderiza la impresión de un listado genérico de los registros de la página actual utilizando la misma información que se utiliza
    *            para renderizarlo en pantalla, ejemplo: el título de la ventana es el título del reporte, las columnas del grid son las del reporte, etc.
  */
  procedure imprimir is
    v_consulta         varchar2(4000);
    v_consulta_lista   varchar2(4000);
    v_alineacion       varchar2(20);
    v_separador        varchar2(20);
    v_estilo           varchar2(1000);
    v_maestro_id       varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');

    v_theCursor        integer default dbms_sql.open_cursor;
    v_columnValue      varchar2(4000);
    v_columnName       varchar2(2000);
    v_status           integer;
    v_descTbl          dbms_sql.desc_tab;
    v_colCnt           number;
    n                  number;
    v_ordenar_por      varchar2(50);
    v_direccion        varchar2(10) := 'ASC';
    v_column_count     number;
    v_from_consulta    varchar2(4000) := null;
    v_filtro_consulta  varchar2(4000) := null;
    v_filtro_valor     varchar2(4000) := null;
    v_name             varchar2(100);
    v_titulo           varchar2(100);

    v_filtro_desc       varchar2(2000);

    v_cant_registro    number:=0;
    v_des         varchar2(1000);
    c             sys_refcursor;

    TYPE matriz_col_id   IS TABLE OF varchar(50);
    TYPE matriz_col_desc IS TABLE OF varchar2(250);
    v_col_id             matriz_col_id;
    v_col_desc           matriz_col_desc;

    TYPE t_valores  IS TABLE OF number(24,6);
    a_valores   t_valores := t_valores();
    a_conteos   t_valores := t_valores();

    v_literal_totales         varchar2(120);
    v_valor_totales           varchar2(120);

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : devolver la colección de caracteristicas de una columna de la coleccion de columnas de una página
      * @p_columna: nombre de la columna cuyas caracteristicas de renderización deseas obtener
    */
    function columna(
      p_columna in varchar2
    )
    return man_det_columnas_paginas_t%ROWTYPE is
    begin
      for i in 1..g_columnas.count loop
        if (g_columnas(i).columna = p_columna) then
           return g_columnas(i);
        end if;
      end loop;
    end;

  begin
      log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Imprimir');

      --- otener el numeros de columnas que se van a imprimir
      select count(*)
      into v_column_count
      from man_det_columnas_paginas_t
      where id_pagina = g_pagina.id_pagina
      and (imprimir = 'S' and tipo_de_dato not in('MCHK','MULTI'));

      -- preparar query para consulta dinamica(que puden venir una vista o un query)
      -- el elemento dinamico "g_pagina.consultar" viene de man_paginas_t y no es input del usuario
      if (lower(g_pagina.consultar) like 'select %' or lower(g_pagina.consultar) like 'with %') then
        v_from_consulta:= ' FROM  ('||g_pagina.consultar||') a';
      else
        v_from_consulta:= ' FROM '||g_pagina.consultar||' a';
      end if;

      -- los elementos dinámicos "g_pagina.campo_id" y "g_pagina.condicion_solo_lectura" vienen de man_paginas_t y no son input del usuario
      v_consulta := 'SELECT '||g_pagina.campo_id ||' rid,'|| case when g_pagina.condicion_solo_lectura is not null then g_pagina.condicion_solo_lectura||' AS SOLO_LECTURA' else  '''N'' AS SOLO_LECTURA' end;
      for i in 1..g_columnas.count
      loop
        if (g_columnas(i).imprimir='S' and g_columnas(i).tipo_de_dato not in ('MCHK','MULTI') ) then /* RJ: para que el campo_id no venga 2 veces en el query si es un campo ID y a la vez editable como id_usuario*/
         -- las columnas dinamicas que se agregan vienen de man_det_columnas_paginas_t y no son input del usuario
         if  (g_columnas(i).expresion is null) then
           v_consulta := v_consulta||','||g_columnas(i).columna;
         else
           v_consulta := v_consulta||','||g_columnas(i).expresion||' as '||g_columnas(i).columna;
         end if;
         if g_formulario.exists('BTN_ORD_'||upper(g_columnas(i).columna)) then
            v_ordenar_por := case  when g_columnas(i).tipo_de_dato in('FEC','DEC','NUM')
                                   then 'a.'||g_columnas(i).columna         -- que saque la columna
                                   else nvl(g_columnas(i).expresion,g_columnas(i).columna) end;
           if  sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION') IS NOT NULL then
               if (upper(g_columnas(i).columna)<> replace(sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO'),'a.','')) then
                  v_direccion := 'ASC';
               else
                  if  sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION') = 'ASC'   then
                     v_direccion := 'DESC';
                  else
                     v_direccion := 'ASC';
                  end if;
               end if;
            else
              v_direccion := 'ASC';
            end if;
         end if;
        end If;
      end loop;

      if (v_ordenar_por is null) then
       if (sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO') is not null) then
         v_ordenar_por := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_CAMPO');
         v_direccion   := sesion_leer(g_id_sesion,g_pagina.id_pagina,'ORD_DIRECCION');
       elsif (g_pagina.ordenar_por is not null) then
         v_ordenar_por := g_pagina.ordenar_por;
         v_direccion   := nvl(g_pagina.ordenar_dir,'ASC');
       end if;
      end if;
      if (lower(v_ordenar_por) not like 'a.%') then
        v_ordenar_por := 'a.'||v_ordenar_por;
      end if;

      v_consulta := v_consulta || v_from_consulta;

      -- adicionando los where condicion que vienen desde filtros
      if sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO') is not null then
         v_filtro_consulta := ' WHERE '|| v_filtro_consulta||' '||g_maestro.campo_id||'='||  ''''||sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO')||'''' ;
      end if;

       for i in 1..g_filtros.count loop
           v_name := 'FILTRO_'||g_filtros(i).secuencia;
           if  sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name) IS NOT NULL then
               if upper(nvl(v_filtro_consulta,'~')) not like '%WHERE%' then
                  v_filtro_consulta := ' WHERE ';
               else
                  v_filtro_consulta:= v_filtro_consulta || ' AND ';
               end if;

              if upper(g_filtros(i).condicion) = 'LIKE' then -- like con collate para que encuentre mayusculs, minusculs o acentos
                 v_filtro_consulta:= v_filtro_consulta|| g_filtros(i).columna;
                 v_filtro_consulta := v_filtro_consulta||' like ''%'||sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name) ||'%'' collate binary_ai';
              elsif upper(g_filtros(i).condicion) = 'LIKE_U' then -- like con upper para que no busque con collate en tablas grandisimas, como seg_usuarios_v
                 v_filtro_consulta:= v_filtro_consulta|| g_filtros(i).columna;
                 v_filtro_consulta := v_filtro_consulta||' like ''%'||upper(sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name))||'%''';
              else
                 v_filtro_consulta:= v_filtro_consulta|| g_filtros(i).columna;
                 if upper(g_filtros(i).tipo_de_dato) = 'FEC' then
                    v_filtro_consulta := v_filtro_consulta||' '||g_filtros(i).condicion ||' to_date('''||sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name) ||''',''dd/mm/yyyy'')';
                 elsif upper(g_filtros(i).tipo_de_dato) = 'NUM' or  upper(g_filtros(i).tipo_de_dato) = 'DEC'then
                    v_filtro_consulta := v_filtro_consulta||' '||g_filtros(i).condicion ||' '||sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name) ||' ';
                 elsif upper(g_filtros(i).tipo_de_dato) = 'CHK' then
                    v_filtro_consulta := v_filtro_consulta||' '||g_filtros(i).condicion ||' ''S''';
                 else
                    v_filtro_consulta := v_filtro_consulta||' '||g_filtros(i).condicion ||' '''||sesion_leer(g_id_sesion,g_pagina.id_pagina,v_name) ||'''';
                 end if;
              end if;

          end if;
          v_filtro_consulta := v_filtro_consulta;
    --      add(v_filtro_consulta||'<br>');
       end loop;
       v_consulta := v_consulta||v_filtro_consulta;

       if v_filtro_consulta is null and g_pagina.id_maestro is not null   then
          v_consulta := v_consulta||' WHERE '|| g_maestro.campo_id||' = ''' ||v_maestro_id||'''';
       end if;

       -- agregando el order by y la direccion de ordenamiento
       v_consulta := v_consulta|| case when v_ordenar_por is not null then ' ORDER BY '||v_ordenar_por||' '||v_direccion end;


       -- comenzamos  a dibujar el html
       add('<html>');
       add('<head>');

       add(' <style>');
       add('  * {font-size: small;}');
       add('  table {width:100%; border-collapse:collapse;}');
       add(' tr {break-inside: avoid;}');
       add('  img {vertical-align:middle;margin:10px 10px}');
       add(' </style>');

       add('</head>');
       add('<body>');

       add('<table cellspacing="3" cellpadding="0" border="0" width="100%">');
       add('<tr>');

       add(' <th align="left" width="1" id="layout_top_logo"><img src="/_images/logo.png" width="50" height="50" ></th>');

       if g_pagina.id_maestro is null then
          add('<th align="Center"><div style="font-size: large;">Reporte de '||g_pagina.titulo||'</div>');
       else
          add('<th align="Center"><div style="font-size: large;">Reporte de '||g_maestro.singular||'</div>');
          v_consulta_lista:= 'select '|| g_maestro.campo_id||','||g_maestro.campo_descripcion ||' FROM ('||g_maestro.consultar||') WHERE '||g_maestro.campo_id ||' = '||
          ''''||sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO')||'''' ;
          begin
            if (lower(v_consulta_lista) like '%:id_inventario%') then
              open c for v_consulta_lista using g_id_inventario;
            else
              open c for v_consulta_lista;
            end if;
          exception when others then
            raise_application_error(-20000,sqlerrm||chr(10)||v_consulta_lista);
          end;

          FETCH c BULK COLLECT INTO v_col_id, v_col_desc;
          v_des := v_col_desc(1);
          add(g_maestro.singular||': '||v_des);

       end if;

       -- filtros de las paginas
       declare
         n_filtros number := 0;
       begin
         for i in 1..g_filtros.count loop
           v_name := 'FILTRO_'||g_filtros(i).secuencia;
           if g_formulario.exists(v_name) and g_formulario(v_name) is not null then
              v_filtro_valor :=  g_formulario(v_name);
              v_filtro_desc  := null;
              if (v_filtro_valor is not null and length(v_filtro_valor)>0) then
                if (g_filtros(i).lista_de_valores is not null) then
                  if (lower(g_filtros(i).lista_de_valores) like 'select%') then
                    -- si es un select
                    DECLARE
                      m_theCursor        integer default dbms_sql.open_cursor;
                      m_colCnt           number;
                      m_descTbl          dbms_sql.desc_tab;
                      m_column           varchar2(32000);
                      m_columnValue      varchar2(4000);
                      m_status           integer;
                    BEGIN
                      -- esta consulta dinamica viene de man_det_filtros_paginas_t, no implementan variables y no requieren input del usuario
                      dbms_sql.parse(m_theCursor, g_filtros(i).lista_de_valores, dbms_sql.native);
                      pasar_parametros(m_theCursor,g_filtros(i).lista_de_valores,null,null);
                      dbms_sql.describe_columns(m_theCursor, m_colCnt, m_descTbl);

                      for j in 1 .. m_colCnt loop
                          dbms_sql.define_column(m_theCursor,j,m_column,4000);
                      end loop;
                      m_status := dbms_sql.execute(m_theCursor); --ignore

                      while(dbms_sql.fetch_rows(m_theCursor) > 0 ) loop
                            for k in 1 .. m_colCnt loop
                                dbms_sql.column_value( m_theCursor, k, m_columnValue );
                                if (m_columnValue = v_filtro_valor) then
                                    dbms_sql.column_value( m_theCursor, k+1,v_filtro_desc);
                                    v_filtro_valor := v_filtro_desc;
                                    exit;
                                end if;
                            end loop;
                      end loop;
                      dbms_sql.close_cursor(m_theCursor);
                    end;
                  else
                    -- si es una lista separada por ,
                    declare
                      v_ini int;
                    begin
                      v_ini        := instr(g_filtros(i).lista_de_valores,v_filtro_valor||'=')+length(v_filtro_valor)+1;
                      v_filtro_desc := substr(g_filtros(i).lista_de_valores,v_ini);
                      if (v_filtro_desc like '%,%') then
                        v_ini        := instr(v_filtro_desc,',')-1;
                        v_filtro_desc := substr(v_filtro_desc,1,v_ini);
                      end if;
                      v_filtro_valor := v_filtro_desc;
                    end;
                  end if;
                end if;

                if upper(g_filtros(i).condicion) = 'LIKE' then
                   v_separador := ' contiene ';
                elsif upper(g_filtros(i).condicion) = 'LIKE_U' then
                   v_separador := ' contiene ';
                   v_filtro_valor := upper(v_filtro_valor);
                elsif upper(g_filtros(i).condicion) = '=' then
                   v_separador := ' igual a ';
                elsif upper(g_filtros(i).condicion) = '>' then
                   v_separador := ' mayor que ';
                elsif upper(g_filtros(i).condicion) = '>=' then
                   v_separador := ' mayor o igual que ';
                elsif upper(g_filtros(i).condicion) = '<' then
                   v_separador := ' menor que ';
                elsif upper(g_filtros(i).condicion) = '<=' then
                   v_separador := ' menor o igual que ';
                elsif upper(g_filtros(i).condicion) = '<>' then
                   v_separador := ' diferente de ';
                elsif upper(g_filtros(i).condicion) = 'IN' then
                   v_separador := ' contenido en ';
                end if;
                if (n_filtros=0) then
                  n_filtros := n_filtros+1;
                  add('<div>Filtros Suministrados:</div>');
                end if;
                add('<div>'||g_filtros(i).titulo||v_separador||'<q>'||v_filtro_valor||'</q></div>');
              end if;
           end if;
         end loop;
       END;
       add('</th>');
       add('<th width="1" align="right" style="white-space:nowrap;">'||to_char(sysdate,'dd/mm/yyyy')||'<br>'||to_char(sysdate,'hh:mi:ss AM')||'</th>');
       add('</tr>');

       add('</table>');

      -- encabezados de las columnas
     add('<table cellspacing="1" cellpadding="3" border="1" width="95%">');
     add('<thead>');
     add('   <tr>');
     n:= 1;
     for i in 1..g_columnas.count loop
         if (g_columnas(i).imprimir='S' and g_columnas(i).tipo_de_dato not in('MCHK','MULTI')) then
             if g_columnas(i).alineacion = 'R'then
                v_alineacion:= ' align="right"';
             elsif  g_columnas(i).alineacion = 'C'then
                   v_alineacion:= ' align="center"';
             else
                  v_alineacion:= '';
             end if;
             n := n +1;
             if (g_columnas(i).prefijo is not null or g_columnas(i).sufijo is not null) then
                 v_titulo := g_columnas(i).prefijo||' '||g_columnas(i).sufijo;
             else
                 v_titulo := g_columnas(i).titulo;
             end if;
            add('<td '||v_alineacion||' style="background-color:silver !important;">'||v_titulo||'</td>');
         end if;
     end loop;
     add('     </tr>');
     add('</thead>');
     add('<tbody>');

     -- preparar la consulta dinamica
     dbms_sql.parse(v_theCursor, v_consulta, dbms_sql.native );
     pasar_parametros(v_theCursor, v_consulta,null,null);
     dbms_sql.describe_columns( v_theCursor, v_colCnt, v_descTbl );
     for i in 1 .. v_colCnt loop
         dbms_sql.define_column(v_theCursor, i, v_columnValue, 4000);
     end loop;
     v_status := dbms_sql.execute(v_theCursor);
    -- esto es colo para quitar el v_status never used
     if (v_status is not null) then null; end if;
    -- inicializar  el areglo de totales
     a_valores.extend(n-1);
     a_conteos.extend(n-1);
    -- iterar los registros que devuelve
     while(dbms_sql.fetch_rows(v_theCursor) > 0 ) loop
          add('<tr>');
            n:=0;
            for i in 3 .. v_colCnt loop -- empezamos en las 5 porque la columna  1,2,3,4 se puso manual
                v_columnName := v_descTbl(i).col_name;

                if columna(v_columnName).alineacion = 'R'then
                   v_alineacion:= ' align="right"';
                elsif columna(v_columnName).alineacion = 'C'then
                   v_alineacion:= ' align="center"';
                else
                      v_alineacion:= '';
                end if;

                if columna(v_columnName).estilo_imprimir is not null then
                  v_estilo := ' style="'||  columna(v_columnName).estilo_imprimir||'"';
                elsif columna(v_columnName).estilo_consultar is not null then
                  v_estilo := ' style="'||  columna(v_columnName).estilo_consultar||'"';
                elsif columna(v_columnName).longitud>=100 then
                  v_estilo := ' style="overflow-wrap: anywhere;"';
                else
                  v_estilo := '';
                end if;

                dbms_sql.column_value( v_theCursor, i, v_columnValue );
                --esto es para que encuentre porqué romper
                if (columna(v_columnName).tipo_de_dato in ('LBL','TXT','MEMO','HTML')) then
                  --esto es porque algunas columnas con valores extra-largos sin espacios nunca rompen
                  v_columnValue := replace(v_columnValue, ',' , ', ');
                  v_columnValue := replace(v_columnValue, ';' , '; ');
                  --limpia espacios duplicados
                  v_columnValue := replace(v_columnValue, ',  ' , ', ');
                  v_columnValue := replace(v_columnValue, ';  ' , '; ');
                end if;

                add(' <td'||v_alineacion||v_estilo||'>'||v_columnValue||'</td>');
                add(' </td>');
                n:= n + 1;
                if columna(v_columnName).tipo_total = 'C' then
                  a_conteos(n):= nvl(a_conteos(n),0)+ 1;
                elsif (v_columnValue is not null) then
                  if (columna(v_columnName).tipo_total in('S','P')) then
                    begin
                      a_valores(n) := nvl(a_valores(n),0) + to_number(v_columnValue);
                      a_conteos(n):= nvl(a_conteos(n),0)+ 1;
                    exception when others then
                      null;
                    end;
                  end if;
                end if;
            end loop;

            add('</tr>');
            v_cant_registro := v_cant_registro + 1;
      end loop;

     dbms_sql.close_cursor(v_theCursor);
     -- footer para botones y paginadort
     add('</tbody>');
     add('<tr>');
     n:= 1;
     for i in 1..g_columnas.count loop
         if (g_columnas(i).imprimir='S' and g_columnas(i).tipo_de_dato not  in('MCHK','MULTI'))  then
            if (n <= a_valores.count)  then

               if g_columnas(i).alineacion = 'R'then
                   v_alineacion:= ' align="right"';
                elsif  g_columnas(i).alineacion = 'C'then
                   v_alineacion:= ' align="center"';
                else
                   v_alineacion:= '';
                end if;

                if g_columnas(i).estilo_consultar is null then
                  v_estilo:= '';
                else
                  v_estilo := ' style="'|| g_columnas(i).estilo_consultar||'"';
                end if;

                if g_columnas(i).tipo_total = 'C' then
                   v_literal_totales:= 'Registros';
                   v_valor_totales := trim(to_char(a_conteos(n),'999,999,990'));
                elsif g_columnas(i).tipo_total = 'S' then
                   v_literal_totales:= 'Total';
                   if (a_valores(n) = trunc(a_valores(n))) then
                     v_valor_totales := trim(to_char(a_valores(n),'999,999,999,999,990'));
                   else
                     v_valor_totales := trim(to_char(a_valores(n),'999,999,999,999,990.00'));
                   end if;
                elsif g_columnas(i).tipo_total = 'P' then
                   v_literal_totales:= 'Promedio';
                   v_valor_totales := trim(to_char(a_valores(n),'999,999,999,999,990.00'));
                else
                   v_literal_totales:= '';
                   v_valor_totales:= '';
                end if;

                add(' <td '||v_alineacion||v_estilo||'><div style="font-size:small; font-style: italic; color: grey;">'||v_literal_totales||'</div>'||v_valor_totales||'</td>');
                n := n + 1;
            end if;
         end if;
     end loop;
     add('</tr>');
     add('</table>');

     add(' </body>');
     add('</html>');
    end imprimir;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : generar reportes personalizados basados en una o mas plantillas html y una o mas sentencias sql
    *            este procedimiento funciona al estilo mail-merge, donde se provee un html que podria contener etiquetas entre corchetes
    *            estas etiquetas, si las hubiere, se buscan en el resultado de la ejecución de la sentencia sql que acompaña al html
    *            y se remplazan por cada registro que devuelva la sentencia, ejemplo:
    *            html: <center>Saludando</center><hr>Hola [USUARIO]!</b>
    *            sql: select distinct usuario from usuarios where tipo='A'   (asumamos que este query devuelve dos registros, admin1 y admin2)
    *            resultado: el reporte a continuacion
    *
    *                                         Saludando
    *            -------------------------------------------------------------------------
    *            Hola ADMIN1!
    *            Hola ADMIN2!
    *
    * @p_reporte: colección con toda la información del reporte a renderizar
    * @p_registros: Id de los registros a renderizar, separados por comma
    * @p_resultado: un clob con la renderizacion html del reporte deseado
  */
  procedure reporte
  is
    type t_bandas    is varray(100) of inv_db.man_det_bandas_reportes_t%ROWTYPE;
    bandas           t_bandas;
    v_html           clob;
    type t_registro  is table of varchar(50);
    v_registros      t_registro;
    v_reg            varchar2(1000);
  begin
    log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Reporte '||g_reporte.reporte);
    
    -- poner en memoria las bandas del reporte
    select b.*
    BULK COLLECT INTO bandas
    from man_det_bandas_reportes_t b
    where b.id_reporte = g_reporte.id_reporte
    and b.estado_registro = 'A'
    order by b.secuencia;

    -- g_registros quita la comma al final
    v_reg := substr(g_registros,1,instr(g_registros,',',-1)-1);

    -- poner en un array los registros que se van a imprimir
    select regexp_substr(v_reg,'[^,]+',1,level)
    BULK COLLECT into v_registros
    from dual connect by level <= length(v_reg)-length(replace(v_reg,','))+1;

    add('<html>');
    if (g_reporte.estilos is not null) then
      add('<style>');
      add(g_reporte.estilos);
      add('</style>');
    end if;
    add(' <body>');

    v_html := null;
    for reg in 1 ..v_registros.count loop
      for i in  1..bandas.count loop
        if bandas(i).consulta is null then
          v_html := v_html||bandas(i).html;
        else
          declare
            v_theCursor        integer default dbms_sql.open_cursor;
            v_columnValue      varchar2(4000);
            v_columnName       varchar2(2000);
            v_status           integer;
            v_descTbl          dbms_sql.desc_tab;
            v_colCnt           number;
            v_banda            clob;
          begin
            -- preparar la consulta dinamica
            dbms_sql.parse( v_theCursor,bandas(i).consulta, dbms_sql.native);
            pasar_parametros(v_theCursor,bandas(i).consulta,'P_REGISTRO',v_registros(reg));
            dbms_sql.describe_columns( v_theCursor, v_colCnt, v_descTbl );
            for i in 1 .. v_colCnt loop
              dbms_sql.define_column(v_theCursor, i, v_columnValue, 4000);
            end loop;
            v_status := dbms_sql.execute(v_theCursor); -- ignore este warning

            while(dbms_sql.fetch_rows(v_theCursor) > 0 ) loop
              v_banda := bandas(i).html;
              for k in 1..v_colCnt loop
                v_columnName := v_descTbl(k).col_name;
                dbms_sql.column_value(v_theCursor,k,v_columnValue );
                --Reemplazar las etiqueta con los valores
                v_banda := replace(v_banda,'['||upper(v_columnName)||']',v_columnValue);
              end loop;
              v_html := v_html||v_banda;
            end loop;
            -- cerrar el cursor
            dbms_sql.close_cursor(v_theCursor);
          exception when others then
            if (dbms_sql.is_open(v_theCursor)) then
              dbms_sql.close_cursor(v_theCursor);
            end if;
            raise;
          end;
        end if ;
      end loop;
    end loop;

    --add(replace(replace(replace(v_html,'<','&lt;'),'>','&gt;'),chr(10),'<br>'));
    add(v_html);

    add(' </body>');
    add('</html>');

  end reporte;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : tomar la data que muestra la página actual, preparar un archivo csv compatible con excel y descargarlo
  */
  procedure exportar is
    m_consulta         varchar2(4000);
    m_consulta_lista   varchar2(4000);
    m_encabezados      varchar2(4000);
    m_alineacion       varchar2(20);
    m_estilo           varchar2(1000);

    l_theCursor        integer default dbms_sql.open_cursor;
    l_columnValue      varchar2(4000);
    l_columnName       varchar2(2000);
    l_status           integer;
    l_descTbl          dbms_sql.desc_tab;
    l_colCnt           number;
    n                  number;
    m_ordenar_por      varchar2(50);
    m_direccion        varchar2(10) := 'ASC';
    m_column_count     number;
    m_from_consulta    varchar2(50) := null;
    m_filtro_consulta  varchar2(2000) := null;
    m_filtro_header    varchar2(2000) := null;
    m_name             varchar2(100);

    m_des         varchar2(1000);
    c             sys_refcursor;
    m_titulo           varchar2(100);

    TYPE matriz_col_id   IS TABLE OF varchar(50);
    TYPE matriz_col_desc IS TABLE OF varchar2(250);
    m_col_id             matriz_col_id;
    m_col_desc           matriz_col_desc;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : devolver la colección de caracteristicas de una columna de la coleccion de columnas de una página
      * @p_columna: nombre de la columna cuyas caracteristicas de renderización deseas obtener
    */
    function columna(
      p_columna in varchar2
    )
    return man_det_columnas_paginas_t%ROWTYPE is
    begin
      for i in 1..g_columnas.count loop
        if (g_columnas(i).columna = p_columna) then
           return g_columnas(i);
        end if;
      end loop;
    end;
  begin
    --- otener el numeros de columnas que se van a exportar
    select count(*)
    into m_column_count
    from man_det_columnas_paginas_t
    where id_pagina = g_pagina.id_pagina
    and (ver IN('S','A','M') and tipo_de_dato not in('MCHK','MULTI'));

    --preparar query para consulta dinamica(que puden venir una vista o un query)

    if (lower(g_pagina.consultar) like 'select %' or lower(g_pagina.consultar) like 'with %') then
      m_from_consulta:= ' FROM  ('||g_pagina.consultar||') a';
    else
      m_from_consulta:= ' FROM '||g_pagina.consultar||' a';
    end if;

    --m_consulta := 'SELECT '||g_pagina.campo_id ||','|| case when g_pagina.condicion_solo_lectura is not null then g_pagina.condicion_solo_lectura||' AS SOLO_LECTURA' else  '''N'''||' AS SOLO_LECTURA' end;
    m_consulta    := 'SELECT ';
    m_encabezados := '<tr>';
    for i in 1..g_columnas.count
    loop
      if (g_columnas(i).ver IN('S','A','M') and g_columnas(i).tipo_de_dato not in('MCHK','MULTI')) then
        m_encabezados := m_encabezados||'<th '||case g_columnas(i).alineacion when 'C' then ' align="center"' when 'R' then ' align="right"' else '' end||' bgcolor="silver">';
        if (g_columnas(i).prefijo is not null or g_columnas(i).sufijo is not null) then
          m_titulo := g_columnas(i).prefijo||' '||g_columnas(i).sufijo;
        else
          m_titulo := g_columnas(i).titulo;
        end if;
        m_encabezados := m_encabezados||m_titulo||'</th>';

        if  (g_columnas(i).expresion is null) then
          m_consulta := m_consulta||g_columnas(i).columna||',';
        else
          m_consulta := m_consulta||g_columnas(i).expresion||' as '||g_columnas(i).columna||',';
        end if;
        if g_formulario.exists('BTN_ORD_'||upper(g_columnas(i).columna))then
          m_ordenar_por := case
                           when g_columnas(i).tipo_de_dato in('FEC','DEC','NUM')
                           then nvl('a.'||g_columnas(i).columna,'ASC')
                           else nvl(g_columnas(i).columna,'ASC')
                           end;
          if g_formulario.exists('ORD_DIRECCION') then
            if (upper(g_columnas(i).columna)<> replace(g_formulario('ORD_CAMPO'),'a.','')) then
              m_direccion := 'ASC';
            else
              if g_formulario('ORD_DIRECCION') = 'ASC'   then
                 m_direccion := 'DESC';
              else
                 m_direccion := 'ASC';
              end if;
            end if;
          end if;
        else
          if g_formulario.exists('ORD_CAMPO') and m_ordenar_por is null  then
            m_ordenar_por := g_formulario('ORD_CAMPO');
          end if;
        end if;
      end If;
    end loop;
    m_encabezados := m_encabezados||'</tr>';
    -- quitar la ultima coma
    m_consulta := substr(m_consulta,1,length(m_consulta)-1);

    m_consulta := m_consulta || m_from_consulta;
    if sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO') is not null then
      m_filtro_consulta := ' WHERE '|| m_filtro_consulta||' '||g_maestro.campo_id||'='|| ''''||sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO')||'''' ;
    end if;

    n := 0;
    for i in 1..g_filtros.count loop
      m_name := 'FILTRO_'||g_filtros(i).secuencia;
      if g_formulario.exists(m_name) and g_formulario(m_name) is not null and length(g_formulario(m_name))>0 then
        n:= n + 1;
        if n = 1 then
          m_filtro_consulta := ' WHERE ';
        else
          m_filtro_consulta:= m_filtro_consulta || ' AND ';
        end if;

        if (n=1) then
          m_filtro_header   := m_filtro_header||'<div>Filtros Suministrados:</div>';
        end if;

        if upper(g_filtros(i).condicion) = 'LIKE' then
          m_filtro_consulta := m_filtro_consulta|| g_filtros(i).columna;
          m_filtro_consulta := m_filtro_consulta||' like ''%'||g_formulario(m_name)||'%'' collate binary_ai';
          m_filtro_header   := m_filtro_header||'<div>'||g_filtros(i).titulo||' contiene "'||g_formulario(m_name)||'"</div>';
        elsif upper(g_filtros(i).condicion) = 'LIKE_U' then
          m_filtro_consulta := m_filtro_consulta|| g_filtros(i).columna;
          m_filtro_consulta := m_filtro_consulta||' like ''%'||upper(g_formulario(m_name))||'%''';
          m_filtro_header   := m_filtro_header||'<div>'||g_filtros(i).titulo||' contiene "'||upper(g_formulario(m_name))||'"</div>';
        else
          m_filtro_consulta := m_filtro_consulta|| g_filtros(i).columna;
          m_filtro_header   := m_filtro_header||'<div>'||g_filtros(i).titulo||' '||g_filtros(i).condicion||' "'||g_formulario(m_name)||'"</div>';
          if upper(g_filtros(i).tipo_de_dato) = 'FEC' then
             m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' to_date('''||g_formulario(m_name) ||''',''dd/mm/yyyy'')';
          elsif upper(g_filtros(i).tipo_de_dato) = 'NUM' or  upper(g_filtros(i).tipo_de_dato) = 'DEC'then
             m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' '||g_formulario(m_name) ||' ';
          elsif upper(g_filtros(i).tipo_de_dato) = 'CHK' then
             m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' ''S''';
          else
             m_filtro_consulta := m_filtro_consulta||' '||g_filtros(i).condicion ||' '''||g_formulario(m_name) ||'''';
          end if;
        end if;

      end if;
      m_filtro_consulta := m_filtro_consulta;
    end loop;
    m_consulta := m_consulta||m_filtro_consulta;
    m_consulta := m_consulta|| case when m_ordenar_por is not null then ' ORDER BY '||m_ordenar_por||' '||m_direccion end;
    add('<html>');
    add('<head><style>td {vertical-align:middle;}</style></head>');
    add('<body>');
    add('<table border="1">');
    add('<tr><th colspan="'||m_column_count||'" align="center">');
    if g_pagina.id_maestro is null then
      add('<div style="font-size:large;">Reporte de '||g_pagina.titulo||'</div>'||m_filtro_header);
    else
      m_consulta_lista := 'select '|| g_maestro.campo_id||','||g_maestro.campo_descripcion
                        || ' FROM ('||g_maestro.consultar||')'
                        || ' WHERE '||g_maestro.campo_id ||'='||''''||sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO')||'''';
      
      open c for m_consulta_lista;
      FETCH c BULK COLLECT INTO m_col_id, m_col_desc;
      m_des := m_col_desc(1);
      add('<div style="font-size:large;">Reporte de '||g_maestro.singular||'</div>'||g_maestro.singular||': '||m_des||m_filtro_header);
    end if;
    add(m_encabezados);
    add('</th></tr>');

    m_consulta := replace(m_consulta,':id_inventario',g_id_inventario);
    m_consulta := replace(m_consulta,':ID_INVENTARIO',g_id_inventario);
    dbms_sql.parse( l_theCursor, m_consulta, dbms_sql.native );
    dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
    for i in 1 .. l_colCnt loop
      dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
    end loop;
    l_status := dbms_sql.execute(l_theCursor);
    if (l_status is not null) then null; end if;
    while(dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
      add('<tr>');
      for i in 1 .. l_colCnt loop -- empezamos en las 5 porque la columna  1,2,3,4 se puso manual
        l_columnName := l_descTbl(i).col_name;

        if (columna(l_columnName).ver in('S','A','M')) then
          if columna(l_columnName).alineacion = 'R' then
             m_alineacion:= ' align="right"';
          elsif columna(l_columnName).alineacion = 'C'then
             m_alineacion:= ' align="center"';
          else
                m_alineacion:= '';
          end if;

          if columna(l_columnName).estilo_consultar is null then
            m_estilo:= '';
          else
            m_estilo := ' style="'||  columna(l_columnName).estilo_consultar||'"';
          end if;

          dbms_sql.column_value( l_theCursor, i, l_columnValue );
          add(' <td'||m_alineacion||m_estilo||'>'||l_columnValue||'</td>');
        end if;
      end loop;
      add('</tr>');
    end loop;

    dbms_sql.close_cursor(l_theCursor);

    add('</table>');
    add('</body>');
    add('</html>');
  end exportar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : descargar (download) como archivo un campo clob/blob del registro actual
  */
  procedure download is
    v_id        varchar2(10);
    v_field     varchar2(100); 
    v_val       varchar2(1000);
    v_sentencia varchar2(1000);
    v_blob      blob;
    v_clob      clob;
    v_step      PLS_INTEGER := 12000; --make sure you set a multiple of 3 not higher than 24573
  begin
    log_acceso(g_id_usuario_procesa,g_pagina.titulo||': Exportar a Excel');

    v_val       := g_formulario('BTN_DOWNLOAD');
    v_id        := substr(v_val,instr(v_val,'id=')+3         , instr(v_val,',field=')    - instr(v_val,'id=')-3);
    v_field     := substr(v_val,instr(v_val,',field=')+7     , instr(v_val,',filename=') - instr(v_val,',field=')-7);
    v_sentencia := 'select '||v_field||' from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:id';

    execute immediate v_sentencia into v_blob using v_id;
       
    FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(v_blob)-1)/v_step) -- last parameter: 
    LOOP 
      v_clob := v_clob || UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(v_blob, v_step, i * v_step + 1)));
    END LOOP;
      
    g_resultado := v_val||','||v_clob;
  end download;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : guardar la trazabilidad de cambios en un registro
    *            ejemplo: al modificar el valor de un campo múltiples veces, la tabla en cuestion solo guarda el último valor y fecha de modificación
    *            la trazabilidad guarda como estaba el registro antes y despues de cada acción individual
    *            los registros de trazabilidad se guardan en la base de datos del módulo de seguridad, si no está disponible se guardan localmente
    * @p_tiempo: Momento de la trazabilidad a guardar, puede ser "antes" o "despues"
    *            al insertar solo se guarda el "despues", al modificar se guardan el "antes" y el "despues" y al borrar solo se gurda el "antes"
    * @p_id_trazabilidad: Id del registro que guarda la trazabilidad (como estaba antes y después) de cualquier modificación
    * @p_accion: Título de la acción (agregar, modificar, borrar, inactivar, etc) que se realiza sobre el registro
    * @p_id_registro: id del registro sobre el que se está accionando
    * @p_resultado: OK|id de la trazabilidad que se guardó (para ser usado en el momento "despues", por ejemplo)
  */
  procedure guardar_trazabilidad (
    p_tiempo              in  varchar2,
    p_id_trazabilidad     in  inv_db.man_trazabilidad_t.id_trazabilidad%type,
    p_accion              in  inv_db.man_trazabilidad_t.accion%type,
    p_id_registro         in  inv_db.man_trazabilidad_t.id_registro%type,
    p_resultado           out varchar2
  ) is
    m_id_trazabilidad number        := p_id_trazabilidad;
    m_accion   varchar2(100);

    m_columnas varchar2(2000) := ',';
    m_consulta varchar2(2000);
    m_campo_id varchar2(2000);

    l_theCursor        integer default dbms_sql.open_cursor;
    l_columnValue      varchar2(4000);
    l_columnName       varchar2(2000);
    l_status           integer;
    l_descTbl          dbms_sql.desc_tab;
    l_colCnt           number;

    m_sysdate          date := sysdate;
  begin
    for cols in (
      select columna col
      from inv_db.man_det_columnas_paginas_t c
      where c.id_pagina = g_pagina.id_pagina
      and c.trazabilidad='S'
    ) loop
      m_columnas := m_columnas||cols.col||',';  -- lista de columnas marcadas para que guarden trazabilidad
    end loop;

    if (length(m_columnas)>1) then
      if (m_id_trazabilidad is null) then
        m_accion := 'insertar';
        begin
          -- insertar en la tabla centralizada
          insert into inv_db.man_trazabilidad_t (
            id_pagina, accion, id_registro, id_usuario, fecha
          ) values (
            g_pagina.id_pagina, p_accion, p_id_registro, g_id_usuario_procesa, m_sysdate
          );
          -- la centralizada es remota y no se puede hacer returning
          select id_trazabilidad
          into m_id_trazabilidad
          from inv_db.man_trazabilidad_t
          where id_pagina = g_pagina.id_pagina

          and accion = p_accion
          and id_registro = p_id_registro
          and id_usuario = g_id_usuario_procesa
          and fecha = m_sysdate;
        end;
      else
        m_accion := 'actualizar';
      end if;

      select 'select * from ('||p.consultar||') x where x.'||p.campo_id||'=:P_ID_REG', p.campo_id
      into m_consulta, m_campo_id
      from inv_db.man_paginas_t p
      where p.id_pagina = g_pagina.id_pagina;

      dbms_sql.parse(l_theCursor, m_consulta, dbms_sql.native );
      pasar_parametros(l_theCursor, m_consulta, 'P_ID_REG',p_id_registro);

      dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl);
      for i in 1 .. l_colCnt loop
        dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
      end loop;
      l_status := dbms_sql.execute(l_theCursor); --ignore

      -- iterar los registros que devuelve
      while(dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
        for i in 1 .. l_colCnt loop
          l_columnName := l_descTbl(i).col_name;
          if (upper(m_columnas) like upper('%,'||l_columnName||',%'))  -- no está es la listra de columnas que guardan trazabilidad
          then
            dbms_sql.column_value( l_theCursor, i, l_columnValue );

            if (m_accion='insertar') then
              if (p_tiempo='antes') then
                --insertar en la tabla centralizada
                insert into inv_db.man_det_trazabilidad_t (id_trazabilidad, columna, antes)
                values (m_id_trazabilidad, l_columnName, l_columnValue);
              elsif (p_tiempo='despues') then
                --insertar en la tabla centralizada
                insert into inv_db.man_det_trazabilidad_t (id_trazabilidad, columna, despues)
                values (m_id_trazabilidad, l_columnName, l_columnValue);
              end if;
            else
              if (p_tiempo='antes') then
                --actualizar en la tabla centralizada
                update inv_db.man_det_trazabilidad_t
                set antes = l_columnValue
                where id_trazabilidad = m_id_trazabilidad
                and columna = l_columnName;
              elsif (p_tiempo='despues') then
                --actualizar en la tabla centralizada
                update inv_db.man_det_trazabilidad_t
                set despues = l_columnValue
                where id_trazabilidad = m_id_trazabilidad
                and columna = l_columnName;
              end if;
            end if;
          end if;
        end loop;
      end loop;

      dbms_sql.close_cursor(l_theCursor);

      p_resultado := 'OK|'||m_id_trazabilidad;
      commit;
    end if;
  end guardar_trazabilidad;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : analizar el input del usuario logueado y preparar la renderización de una página, en cualquiera de sus posibles estados
    *            consultando en un grid, viendo los detalles de la pagina actual, viendo la documentacion de ayuda de la pagina actual,
    *            sorteando, filtrando, imprimiendo o exportando los datos en pantalla,
    *            viendo, agregando, modificando, borrando o realizando otras acciones sobre los registros
    *            graficando o imprimiendo reportes personalizados , etc.
    *            por ejemplo:
    *            entras a la página de parametros   -> man_preparar_p llama a man_consultar_p y ves un grid de parámetros
    *            haces click en un parametro        -> man_preparar_p si tienes permiso de modificar llama a man_modificar_p y ves la página de editar
    *                                               -> man_preparar_p si no tienes permiso de modificar llama a man_ver_p y ves la página de mirar
    *            haces click en el boton de back    -> man_preparar_p llama a man_consultar_p y ves un grid de parametros
    * @p_id_pagina: Id de la pagina actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_usuario_procesa: Id del usuario logueado
    * @p_formulario: Colección de los valores de todos los input-controls en el último post-back
    * @p_resultado: un clob que contiene la renderizacion html de la pagina en el estado que se desea
  */
  procedure preparar(
    p_id_pagina          in out varchar2,
    p_id_sesion          in man_sesiones_t.id_sesion%type,
    p_id_usuario_procesa in varchar2,
    p_formulario         in clob,
    p_resultado          OUT CLOB
  ) is
    m_msg_tmp         varchar2(4000);
    m_pk_id           varchar2(1000);
    m_traz_id         int;
    m_res_traz        varchar2(1000);

    m_cant_error      int := 0;
    m_mensajes_texto  varchar2(4000);
    m_mensajes_tipo   varchar2(15);

    i                 PLS_INTEGER  := 0;
    m_accion          varchar2(15) := '';
    m_reporte_id      number(9);

    m_key             varchar2(100);
    m_boton_de_accion int;
    m_sp_ejecutar     varchar2(100);
    m_sp_accion      varchar2(100);
    m_id_error        int;
    m_pagina_anterior varchar2(10);
    m_filtros_llenos_antes int := 0;

    empty_formulario  man_mantenimientos_pkg.t_formulario;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : llenar las diferentes colecciones de datos que requieren tener permiso 
      * @p_pagina: Id de la página
    */
    procedure crear_objetos_permisibles is
    begin
      -- poner en memoria las acciones
      select dap.*
      bulk collect into g_acciones
      from inv_db.man_det_acciones_paginas_t dap
      join inv_db.seg_usuarios_permisos_v up on up.id_usuario = p_id_usuario_procesa and up.id_permiso=dap.id_permiso
      where dap.id_pagina = g_pagina.id_pagina
      and dap.estado_registro='A'
      order by dap.secuencia;

       -- tabs que se deben mostrar junto a esta página detalle
      select *
      BULK COLLECT INTO g_tabs
      from man_det_tabs_paginas_v t
      where t.id_usuario = g_id_usuario_procesa
      and t.id_maestro = g_pagina.id_maestro
      order by t.secuencia asc;

      -- si se muestra el boton de tabs
      select count(*)
      into g_puede_ver_tabs
      from man_det_tabs_paginas_v t
      where id_usuario = g_id_usuario_procesa
      and id_maestro = g_pagina.id_pagina;

      -- determinar si se podrá consultar
      if (lower(g_pagina.consultar) like '%:id_inventario%' and g_id_inventario is null) then
        -- esta pagina requiere ser un usuario registrado en un inventario
        g_puede_consultar  := 'N';
        g_puede_agregar    := 'N';
        g_puede_modificar  := 'N'; 
        g_puede_borrar     := 'N';
        g_pag_solo_lectura := 'S';
      else
        if (g_pagina.id_permiso_consultar is null) then
          g_puede_consultar := 'S';                 -- esta pagina no requiere permiso para consultar, todos pueden consultar, como el buzon o el perfil
        else
          select decode(count(*),0,'N','S')         -- esta pagina requiere permiso para consultar, ver si el usuario lo tiene
          into g_puede_consultar
          from seg_usuarios_permisos_v
          where id_usuario=g_id_usuario_procesa and id_permiso=nvl(g_pagina.id_permiso_consultar,0);
        end if;

        -- determinar si se podrá agregar
        if (g_pagina.agregar is null) then
          g_puede_agregar := 'N';                        -- esta pagina no agrega
        elsif (g_pagina.id_permiso_agregar is null) then
          g_puede_agregar := 'S';                        -- esta pagina agrega pero no requiere permiso, todos pueden agregar
        else
          select decode(count(*),0,'N','S')            -- esta pagina agrega y requiere permiso, ver si el usuario lo tiene
          into g_puede_agregar
          from seg_usuarios_permisos_v
          where id_usuario=g_id_usuario_procesa and id_permiso=nvl(g_pagina.id_permiso_agregar,0);
        end if;

        -- determinar si se podrá modificar
        if (g_pagina.modificar is null) then
          g_puede_modificar := 'N';                      -- esta pagina no modifica
        elsif (g_pagina.id_permiso_modificar is null) then
          g_puede_modificar   := 'S';                    -- esta pagina modifica pero no requiere permiso, todos pueden modificar
        else
          select decode(count(*),0,'N','S')            -- esta pagina modifica y requiere permiso, ver si el usuario lo tiene
          into g_puede_modificar
          from seg_usuarios_permisos_v
          where id_usuario=g_id_usuario_procesa and id_permiso=nvl(g_pagina.id_permiso_modificar,0);
        end if;

        -- determinar si se podrá borrar
        if (g_pagina.borrar is null) then
          g_puede_borrar := 'N';                         -- esta pagina no borra
        elsif (g_pagina.id_permiso_borrar is null) then
          g_puede_borrar   := 'S';                       -- esta pagina borra pero no requiere permiso, todos pueden borrar
        else
          select decode(count(*),0,'N','S')            -- esta pagina borra y requiere permiso, ver si el usuario lo tiene
          into g_puede_borrar
          from seg_usuarios_permisos_v
          where id_usuario=g_id_usuario_procesa and id_permiso=nvl(g_pagina.id_permiso_borrar,0);
        end if;

        if (g_pagina.agregar is null and g_pagina.modificar is null) then
          g_pag_solo_lectura := 'S';
        else
          g_pag_solo_lectura := case when g_puede_modificar='S' then 'N' else 'S' end;
        end if;
        
        -- por ultimo, si una pagina es un detalle y su maestro tiene una condicion de solo lectyura que se cumple, esta pagina será de solo lectura
        if (g_pagina.id_maestro is not null and g_maestro.condicion_solo_lectura is not null) then
          declare
            m_sql  varchar2(4000);
            m_cond varchar2(1);
            m_maestro_id  varchar2(1000) := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_MAESTRO');
          begin
            -- los elementos dinamicos "g_pagina.condicion_solo_lectura", "g_maestro.consultar" y "g_maestro.campo_id" vienen de man_paginas_t y no son input del usuario
            -- el m_id es input del usuario y está parametrizado
            m_sql  := 'select '||g_maestro.condicion_solo_lectura||' as condicion from ('||g_maestro.consultar||') where '||g_maestro.campo_id||'=:M_MAS_ID';
            m_cond := ejecutar(m_sql,'M_MAS_ID',m_maestro_id);
            if (m_cond='S') then
              g_puede_consultar  := 'S';
              g_puede_agregar    := 'N';
              g_puede_modificar  := 'N'; 
              g_puede_borrar     := 'N';
              g_pag_solo_lectura := 'S';
            end if;
          exception when others then
            -- no hacer nada, dejarlo a discreción del usuario hasta nuevo aviso
            null;
          end;
        end if;
      end if;
    end;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : llenar las diferentes colecciones de datos (pagina, columnas, filtros,acciones, etc) de la pagina actual
      * @p_pagina: Id de la página
    */
    procedure crear_objetos(
      p_pagina man_paginas_t.id_pagina%type
    ) is
    begin
      -- cambiar la pagina actual
      p_id_pagina := p_pagina;

      -- llenar globales
      g_id_usuario_procesa := p_id_usuario_procesa;
      g_id_inventario      := to_number(g_formulario('ID_INVENTARIO'));
      g_id_sesion          := p_id_sesion;
     
      -- poner en memoria la pagina
      select *
      into g_pagina
      from man_paginas_t
      where id_pagina = p_pagina;

      -- si cambió de maestro dandole al LOV de arriba     
      if (g_formulario.exists('LOV_MAESTRO') and g_formulario('LOV_MAESTRO')<>nvl(sesion_leer(g_id_sesion,g_pagina.id_pagina,'ID_MAESTRO'),'~~~')) 
      then
        sesion_guardar(
          p_id_sesion,
          g_id_usuario_procesa,
          g_pagina.id_pagina,
          'ID_MAESTRO',
          g_formulario('LOV_MAESTRO')
        );
        -- cambiaron de maestro, borrar cualquier control txt_ (pantallas tipo A y E) porque al cambiar de maestro esos valores ya no le pertenecen
        declare
          m_key varchar2(100);
        begin
          m_key := g_formulario.FIRST;
          WHILE (m_key IS NOT NULL) LOOP
            if  (SUBSTR(m_key,1,4)='TXT_') then
              g_formulario.delete(m_key);
            end if;
            m_key := g_formulario.NEXT(m_key);
          END LOOP;
        end;
      end if;

      -- si es una pagina tipo E (solo edicion) debe traer un solo registro, ponerlo en la sesion
      if (g_pagina.tipo='E') then
        declare
          m_id varchar2(100);
        begin
          m_id := ejecutar('select z.'||g_pagina.campo_id||' from ('||g_pagina.consultar||') z'); -- este query solo debe traer 1 registro
          sesion_guardar(p_id_sesion, g_id_usuario_procesa, g_pagina.id_pagina,'ID_REGISTRO',m_id);
        end;
      end if;

      -- poner en memoria la pagina
      if (g_pagina.id_maestro is null) then
        g_maestro := null;
      else
        select *
        into g_maestro
        from man_paginas_t
        where id_pagina = g_pagina.id_maestro;
      end if;

     -- poner en memoria las columnas
      select *
      bulk collect into g_columnas
      from man_det_columnas_paginas_t
      where id_pagina = g_pagina.id_pagina
      and estado_registro='A'
      order by secuencia;

      -- determinar si esta pagina guarda trazabilidad
      g_trazabilidad := 'N';
      for t in 1..g_columnas.count loop
        if (g_columnas(t).trazabilidad='S') then
          g_trazabilidad := 'S';
          exit;
        end if;
      end loop;

      -- poner en memoria los filtros
      select f.*
      BULK COLLECT INTO g_filtros
      from man_det_filtros_paginas_t f
      where f.id_pagina = g_pagina.id_pagina
      and f.estado_registro='A'
      order by f.secuencia;

      -- poner en memoria los reportes
      select r.*
      bulk collect into g_reportes
      from man_reportes_t r
      where id_pagina = g_pagina.id_pagina
      and exists (select * from  inv_db.man_det_bandas_reportes_t where id_reporte = r.id_reporte)
      and estado_registro='A'
      order by secuencia;
      g_reportes_multi := 0;
      g_reportes_uni   := 0;
      for n in 1..g_reportes.count loop
        if (g_reportes(n).seleccion_multiple='S') then
          g_reportes_multi := g_reportes_multi+1;
        else
          g_reportes_uni   := g_reportes_uni+1;
        end if;
      end loop;

      -- cargar los objetos permisibles (que requieren permisos, como las acciones o los detalles de esta página)
      crear_objetos_permisibles;
    end;

    /**
      * Autor    : Roberto Jaquez & Fausto Montero
      * Fecha    : 21/10/2024
      * Objetivo : determinar la siguiente acción correspondiente segun el input del usuario
      *            ejemplo: si es una pagina que solo grafica, solo agrega o solo modifica: se redirige a esa accion
      *                     si es un mantenimiento: si se hizo click en un tab, un detalle o al boton regresar entonces  se dirige a consultar
      *                     si hizo click en un registro y tiene permiso de modificar se digige a modificar, si no tiene se dirige a ver el registro,
      *                     etc.
    */
    procedure accion_por_tipo_de_pagina is
    begin
      if g_pagina.tipo in ('B','P','L') then
        m_accion := 'graficar';
      elsif g_pagina.tipo = 'A' then
        m_accion := 'agregar';
      elsif g_pagina.tipo = 'E' then
        m_accion := 'modificar';
      elsif g_pagina.tipo = 'M' then
        if (p_formulario like '%BTN_TAB_%' or p_formulario like '%BTN_DET_%' or p_formulario like '%BTN_REGRESAR%') then
          -- estoy cambiando de pagina a una tipo M, por default va a consultar
          m_accion := 'consultar';
        else
          -- estoy en una tipo M pero no estoy cambiando de pagina, hay que determinar si esoty agregando o modificando
          -- si existe reg en el query string ir a ese registro
          declare
            m_key varchar2(100);
          begin
            m_key := g_formulario.FIRST;
            WHILE (m_key IS NOT NULL) LOOP
              if (lower(m_key)='reg') then
                sesion_guardar(p_id_sesion,g_id_usuario_procesa,p_id_pagina,'REGISTRO',g_formulario(m_key));
                m_accion := 'modificar';
                exit;
              end if;
              m_key := g_formulario.NEXT(m_key);
            END LOOP;

            if (p_formulario like '%BTN_BUSCAR%') then
              if (p_formulario like '%'||inv_db.seg_autenticacion_pkg.md5('add')||'%') then
                m_accion := 'agregar';
              elsif (p_formulario like '%'||inv_db.seg_autenticacion_pkg.md5('upd')||'%') then
                m_accion := 'modificar';
              else
                m_accion := 'consultar';
              end if;
            else
              if (p_formulario like '%'||inv_db.seg_autenticacion_pkg.md5('add')||'%' and  p_formulario not like '%BTN_INSERTAR%') then
                m_accion := 'agregar';
              elsif (p_formulario like '%'||inv_db.seg_autenticacion_pkg.md5('upd')||'%'  and  p_formulario not like '%BTN_MODIFICAR%') then
                m_accion := 'modificar';
              else
                m_accion := 'consultar';
              end if;
            end if;
          end;
        end if;
      end if;
    end;

  BEGIN
   -- antes que todo: reiniciar todas las variables globales
   g_id_sesion          := p_id_sesion;
   g_id_usuario_procesa := p_id_usuario_procesa;
   g_puede_consultar    := 'N';
   g_puede_agregar      := 'N';
   g_puede_modificar    := 'N';
   g_puede_borrar       := 'N';
   g_resultado          := null;
   g_pagina             := null;
   g_maestro            := null;
   g_reporte            := null;
   g_puede_ver_tabs     := null;
   g_pag_solo_lectura   := null;
   g_registros          := null;
   g_columnas           := null;
   g_filtros            := null;
   g_reportes           := null;
   g_reportes_multi     := null;
   g_reportes_uni       := null;
   g_acciones           := null;
   g_tabs               := null;
   g_resultado          := null;
   g_valores_parametros := null;
   g_formulario         := empty_formulario;
   g_registro           := empty_formulario;

   -- si la pagina es un string, encontrar el id
   if (not REGEXP_LIKE(p_id_pagina, '^[[:digit:]]+$')) then
     begin
       select id_pagina
       into p_id_pagina
       from man_paginas_t
       where titulo = p_id_pagina;
     exception when no_data_found then
       p_id_pagina := -1;
     end;
   end if;

   select count(*)
   into i
   from man_paginas_t
   where id_pagina = p_id_pagina;

   if (i>0) then
    --preparar y desencriptar el formulario para poder usarse en loops
    if (p_formulario is not null) then
      for field in (
        SELECT x.*
        FROM dual m
        CROSS JOIN
        XMLTABLE ('/fields/field' PASSING xmltype (p_formulario) COLUMNS key varchar2(100) path 'key', val clob PATH 'val') x
      ) loop
        declare
          f_key varchar2(100)  := field.key;
          f_val clob           := field.val;
        begin
          if (f_key like 'CHK_REGISTRO_%') then
            f_key := 'CHK_REGISTRO_'||man_mantenimientos_pkg.decrypt(substr(f_key,14,999));
          elsif (f_key like 'LINK_VER_%') then
            f_key := 'LINK_VER_'||man_mantenimientos_pkg.decrypt(substr(f_key,10,999));
          elsif (upper(f_key)='REG') then
            f_key := 'REG';
          elsif (f_key like 'BTN_DET_%') then
            f_key := 'BTN_DET_'||man_mantenimientos_pkg.decrypt(substr(f_key,9,999));
            f_val := substr(f_key,9,999);
          elsif (f_key like 'BTN_TAB_%') then
            f_key := 'BTN_TAB_'||man_mantenimientos_pkg.decrypt(substr(f_key,9,999));
            f_val := substr(f_key,9,999);
          elsif (f_key like 'BTN_REGRESAR') then
            f_val := man_mantenimientos_pkg.decrypt(f_val);
          elsif (f_key like 'BTN_DOWNLOAD') then
            f_val := man_mantenimientos_pkg.decrypt(f_val);
          elsif (f_key like 'BTN_REPORTE_') then
            f_key := 'BTN_REPORTE_'||man_mantenimientos_pkg.decrypt(substr(f_key,13,999));
          end if;
          if (SUBSTR(f_key,1,7)='FILTRO_') then
            if (p_formulario not like '%BTN_LIMPIAR%') then
                g_formulario(f_key) := f_val;
            end if;
          else
            g_formulario(f_key) := f_val;
          end if;
        exception when others then
          m_mensajes_texto := m_mensajes_texto||'|Error de seguridad ';
          m_mensajes_tipo  := 'error';
        end;
      end loop;

      --si presiono limpar, quitar los filtros
      if (p_formulario like '%BTN_LIMPIAR%') then
        delete from inv_db.man_sesiones_t s
        where s.id_sesion = p_id_sesion
        and s.id_usuario = g_id_usuario_procesa
        and s.id_pagina = p_id_pagina
        and s.llave like 'FILTRO_%';
        commit;
      end if;
    end if;

    -- recordar si habia algun filtro lleno antes
    select count(*)
    into m_filtros_llenos_antes
    from inv_db.man_sesiones_t
    where id_sesion=g_id_sesion
    and id_usuario=g_id_usuario_procesa
    and id_pagina=p_id_pagina
    and llave like 'FILTRO%'
    and valor is not null;

    -- primero paginador y los botones de ordenar y filtrar
    m_pagina_anterior := nvl(sesion_leer(p_id_sesion,p_id_pagina,'PAGINADOR'),'1');

    if (m_mensajes_texto is null) then
      -- guardar los valores actuales de la sesion(solo si no estamos haciendo back)
      if (not g_formulario.exists('BTN_REGRESAR')) then
        declare
          m_key varchar2(100);
          x_key varchar2(100);
          x_val clob;
        begin
          -- primero paginador y los botones de ordenar y filtrar
          m_key := g_formulario.FIRST;
          WHILE (m_key IS NOT NULL) LOOP
            x_key := m_key;
            x_val := g_formulario(m_key);
            if (m_key in ('PAGINADOR','ORD_CAMPO','ORD_DIRECCION') or m_key like 'BTN_ORD_%' or m_key like 'FILTRO_%') then
              if (x_key like 'BTN_ORD_%') then
                x_key := 'ORD_CAMPO';
                x_val := replace(m_key,'BTN_ORD_','');
                if (g_formulario.exists(x_key)) then
                   g_formulario(x_key) := x_val;
                end if;
              end if;
              if (x_key like 'FILTRO_%') then
                x_val := man_formatear_pkg.htmlDecode(x_val);
              end if;
              sesion_guardar(p_id_sesion,g_id_usuario_procesa,p_id_pagina,x_key,x_val);
            end if;

            m_key := g_formulario.NEXT(m_key);
          END LOOP;

          -- segundo los botones de moverse de pagina (sobreescriben lo que haya dicho paginador)
          m_key := g_formulario.FIRST;
          WHILE (m_key IS NOT NULL) LOOP
            x_key := m_key;
            x_val := g_formulario(m_key);
            if (m_key in ('PAGINA_PRIMERA','PAGINA_ANTERIOR','PAGINA_SIGUIENTE','PAGINA_ULTIMA')) then
              sesion_guardar(p_id_sesion,g_id_usuario_procesa,p_id_pagina,'PAGINADOR',x_val);
              exit; -- sal del loop, de esos 4 botones solo llega uno a la vez
            end if;
            m_key := g_formulario.NEXT(m_key);
          END LOOP;

          commit;
        end;
      end if;

      -- llenar los objetos
      if (g_formulario.exists('ID_PAGINA')) then
        p_id_pagina := g_formulario('ID_PAGINA');
      end if;
      crear_objetos(p_id_pagina);
      
      -- Accion default por tipo de pantalla
      accion_por_tipo_de_pagina();

      -- Ver si se presionó un boton de accion
      m_boton_de_accion := null;
      m_key := g_formulario.FIRST;
      WHILE (m_key IS NOT NULL) LOOP
        if (m_key like 'BTN_ACCION_%') then
          m_boton_de_accion := substr(m_key,12);
          exit;
        end if;
        m_key := g_formulario.NEXT(m_key);
      END LOOP;

      if g_formulario.exists('BTN_AYUDA') then
        m_accion := 'ayuda';
      elsif g_formulario.exists('BTN_VOLVER') then
        m_accion := 'consultar';
      elsif g_formulario.exists('BTN_FILTRAR') then
        -- puede ser una de dos, o presinó el boton filtrar o escribió algo en la pagina #
        if not (g_formulario.exists('PAGINADOR') and g_formulario('PAGINADOR') <> m_pagina_anterior) then
          --presionó el boton filtrar
          declare
            z_key varchar2(100);
            z_val varchar2(32000);
            z_fil number := 0;
          begin
            z_key := g_formulario.FIRST;
            WHILE (z_key IS NOT NULL) LOOP
              z_val := g_formulario(z_key);
              if (z_key like 'FILTRO_%' and trim(z_val) is not null) then
                z_fil := z_fil+1;
              end if;
              z_key := g_formulario.NEXT(z_key);
            END LOOP;
            if (z_fil>0) then
              --puso filtros, ir a pagina 1
              sesion_guardar(p_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'PAGINADOR',1);
            else
              -- presiono filtrar pero sin filtros, ver si antes habia algun filtro
              if (m_filtros_llenos_antes=0) then
                m_mensajes_texto := 'Debe especificar un criterio de búsqueda.';
                m_mensajes_tipo  := 'warning';
              end if;
            end if;
          end;
        end if;
        m_accion := 'consultar';
      elsif g_formulario.exists('BTN_REGRESAR') then
        for i in 1..g_tabs.count loop
          delete from man_sesiones_t s
          where s.id_sesion = g_id_sesion
          and s.id_usuario = g_id_usuario_procesa
          and s.id_pagina = g_tabs(i).id_pagina;
        end loop;
        commit;

        g_formulario.delete('ID_PAGINA');
        g_formulario.delete('LOV_MAESTRO');
        crear_objetos(cast(g_formulario('BTN_REGRESAR') as varchar2));
        accion_por_tipo_de_pagina();
      elsif (p_formulario like '%BTN_REPORTE_%') then -- presionaron uno de los botones de reporte
        -- determinar cual reporte
        declare
          key varchar2(100);
          val varchar2(100);
          msg varchar2(2000);
        begin
          key := g_formulario.FIRST;
          WHILE (key IS NOT NULL) LOOP
            if (key like 'BTN_REPORTE_%') then
                val := substr(key,13);
                m_reporte_id := man_mantenimientos_pkg.decrypt(val);
                exit;
            end if;
            key := g_formulario.NEXT(key);
          END LOOP;
        end;

        select *
        INTO g_reporte
        from inv_db.man_reportes_t r
        where r.id_reporte =  m_reporte_id;

        -- determinar cual o cuales registros
        if (sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO') is not null) then
          -- la variable de session ID_REGISTRO esta llena, le dieron click a imprimir en la pagina de ver/modificar
          -- esta rutina se ejecuta cuando se imprime un reporte personalizado que tiene lleno el campo sentencia
          -- porque hay reportes que al imprimirse tienen que marcar algun campo como "IMPRESO"
          declare
            msg varchar2(2000);
          begin
            if g_reporte.sentencia is not null then
              -- los parametros de ejecución de este procedure ya estan parametrizados
              execute immediate 'begin '||g_reporte.sentencia|| '(:p_usr,:p_reg,:m_res); end;'
              using in g_id_usuario_procesa, in sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO'), out msg;

              if (msg not like 'OK|%') then
                 m_cant_error  := 1;
                 m_mensajes_texto := substr(msg,4);
                 m_mensajes_tipo  := 'error';
              end if;
            end if;
          end;
          g_registros := sesion_leer(g_id_sesion, g_pagina.id_pagina,'ID_REGISTRO')||',';
          m_accion    := 'reporte';
        else
          -- la variable de session ID_REGISTRO esta vacia, le dieron click a imprimir en la pagina de consultar
          -- esta rutina se ejecuta cuando se imprime un reporte personalizado que tiene lleno el campo sentencia
          -- porque hay reportes que al imprimirse tienen que marcar algun campo como "IMPRESO"
          declare
             sen varchar2(32000);
             key varchar2(100);
             val varchar2(100);
             m_conteo int := 0;
             msg varchar2(2000);
             reg_desc varchar2(1000);
          begin
             g_registros := null;
             key := g_formulario.FIRST;
             WHILE (key IS NOT NULL) LOOP
                if (key like 'CHK_REGISTRO_%') then
                   val := substr(key,14);
                   g_registros := g_registros||val||',';
                    m_conteo := m_conteo+1;
                    if g_reporte.sentencia is not null then
                       -- encontrar la descripcion del registro
                       sen      := 'select '||g_pagina.campo_descripcion||' from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:P_REG';
                       reg_desc := ejecutar(sen,'P_REG',val);

                       -- los parametros de ejecución de este procedure ya estan parametrizados
                       execute immediate 'begin '||g_reporte.sentencia|| '(:p_usr,:p_reg,:m_res); end;'
                       using in g_id_usuario_procesa, in val, out msg;

                       if (msg not like 'OK|%') then
                           m_cant_error  := m_cant_error+1;
                           if (m_mensajes_texto is not null) then
                               m_mensajes_texto := m_mensajes_texto||'<br>';
                           end if;
                           m_mensajes_texto := m_mensajes_texto||reg_desc||': '||substr(msg,4);
                           m_mensajes_tipo  := 'error';
                       end if;
                    end if;
                end if;
                key := g_formulario.NEXT(key);
             END LOOP;
             if (m_conteo=0) then
                  m_mensajes_texto := 'Debe seleccionar al menos un registro.';
                  m_mensajes_tipo  := 'warning';
             else
                  m_accion := 'reporte';
             end if;
          end;
        end if;
      elsif g_formulario.exists('BTN_IMPRIMIR') then
        m_accion := 'imprimir';
      elsif g_formulario.exists('BTN_EXPORTAR') then
        m_accion := 'exportar';
      elsif g_formulario.exists('BTN_DOWNLOAD') then
        m_accion := 'download';
      elsif g_formulario.exists('BTN_AGREGAR') then
        if (g_puede_agregar='S') then
          m_accion := 'agregar';
        else
          m_mensajes_texto := 'Usted no tiene permiso de agregar registros.';
          m_mensajes_tipo  := 'error';
          m_accion         := 'consultar';
        end if;
      elsif (g_formulario.exists('BTN_INSERTAR') or g_formulario.exists('BTN_MODIFICAR')) then
        m_accion := 'consultar';
        if (g_formulario.exists('BTN_INSERTAR') and g_puede_agregar='S') then
          m_accion := 'agregar';
        end if;
        if (g_formulario.exists('BTN_MODIFICAR') and g_puede_modificar='S') then
          m_accion := 'modificar';
        end if;

        if (m_accion in('agregar','modificar')) then
          declare
            x_col varchar2(100);
            x_tit varchar2(100);
            x_val varchar2(32000);
            x_err varchar2(1000);
            tmp_fec date;
          begin
            -- primero se validan los requeridos,longitud maxima,minimo,maximo y regexp, y que el valor seleccionado esté en su lista de valores
            for i in 1..g_columnas.count loop

             if (m_accion='agregar'   and g_columnas(i).agregar='S')
             or (m_accion='modificar' and g_columnas(i).modificar='S')
             then
              x_col := g_columnas(i).columna;
              x_tit := nvl(g_columnas(i).titulo,x_col);
              if (upper(substr(g_columnas(i).columna,1,2))='P_' and g_formulario.exists('TXT_'||upper(substr(g_columnas(i).columna,3,99)))) then
                x_val := g_formulario('TXT_'||upper(substr(g_columnas(i).columna,3,99)));
              elsif (g_formulario.exists('TXT_'||g_columnas(i).columna)) then
                x_val := g_formulario('TXT_'||g_columnas(i).columna);
              else
                if (g_columnas(i).tipo_de_dato in('DOC','IMG')) then
                  select count(*)
                  into x_val
                  from inv_db.man_sesiones_t s
                  where s.id_sesion = g_id_sesion
                  and s.id_usuario = g_id_usuario_procesa
                  and s.id_pagina = g_pagina.id_pagina
                  and s.llave = 'TXT_'||g_columnas(i).columna
                  and s.valor is not null
                  and s.documento is not null;
                  if (x_val=0) then
                    x_val := null;
                  end if;
                else
                  x_val := null;
                end if;
              end if;
              if (x_val is null or trim(x_val) is null or length(x_val)=0) then
                -- requerido
                if (g_columnas(i).requerido='S' and g_columnas(i).tipo_de_dato not in('LBL','UL','OL','CHK','MULTI','MCHK')) then
                  x_err := x_err||'|El campo '||x_tit||' no debe ser dejado en blanco.';
                end if;
              else
                -- txt,memo
                if (g_columnas(i).tipo_de_dato in('TXT','PASS','MEMO') and length(x_val)>g_columnas(i).longitud) then -- txt,memo
                  x_err := x_err||'|El campo '||x_tit||' no debe sobrepasar los '||g_columnas(i).longitud||' caracteres.';
                elsif (g_columnas(i).tipo_de_dato in('NUM','DEC','FLOAT')) then                                        -- num
                  declare
                    m_num number(24,6);
                    v_min number(24,6);
                    v_max number(24,6);
                  begin
                    -- si es un numero
                    m_num := to_number(replace(x_val,',',''));
                    if (g_columnas(i).tipo_de_dato='NUM' and trunc(m_num)<>to_number(replace(x_val,',',''))) then
                      -- si es un entero
                      x_err := x_err||'|El campo '||x_tit||' no es un número entero válido.';
                    else
                      if (g_columnas(i).tipo_de_dato='NUM'   and m_num not between to_number(rpad('9',g_columnas(i).longitud  ,'9'))*-1 and to_number(rpad('9',g_columnas(i).longitud  ,'9'))) then
                        x_err := x_err||'|El campo '||x_tit||' no debe sobrepasar '||g_columnas(i).longitud||' dígito'||case when g_columnas(i).longitud=1 then '' else 's' end||'.';
                      elsif (g_columnas(i).tipo_de_dato='DEC'   and m_num not between to_number('-'||rpad('9',g_columnas(i).longitud-2,'9')||'.99') and to_number(rpad('9',g_columnas(i).longitud-2,'9')||'.99')) then
                        x_err := x_err||'|El campo '||x_tit||' no debe sobrepasar '||(g_columnas(i).longitud-2)||' dígito'||case when g_columnas(i).longitud-2=1 then '' else 's' end||' con 2 decimales máximo.';
                      elsif (g_columnas(i).tipo_de_dato='FLOAT'   and m_num not between to_number('-'||rpad('9',g_columnas(i).longitud-6,'9')||'.999999') and to_number(rpad('9',g_columnas(i).longitud-6,'9')||'.999999')) then
                        x_err := x_err||'|El campo '||x_tit||' no debe sobrepasar '||(g_columnas(i).longitud-6)||' dígito'||case when g_columnas(i).longitud-6=1 then '' else 's' end||' con 6 decimales máximo.';
                      else
                        if (g_columnas(i).valor_minimo is not null) then
                          if (lower(g_columnas(i).valor_minimo) like 'select %' or lower(g_columnas(i).valor_minimo) like 'with %') then
                            v_min := ejecutar(g_columnas(i).valor_minimo);
                          else
                            v_min := to_number(cast(g_columnas(i).valor_minimo as varchar2));
                          end if;
                          if (m_num<v_min) then
                            x_err := x_err||'|El campo '||x_tit||' no debe ser menor que '||v_min||'.';
                          end if;
                        end if;
                        -- max
                        if (g_columnas(i).valor_maximo is not null) then
                          if (lower(g_columnas(i).valor_maximo) like 'select %' or lower(g_columnas(i).valor_maximo) like 'with %') then
                            v_max := ejecutar(g_columnas(i).valor_maximo);
                          else
                            v_max := to_number(cast(g_columnas(i).valor_maximo as varchar2));
                          end if;
                          if (m_num>v_max) then
                            x_err := x_err||'|El campo '||x_tit||' no debe ser mayor que '||v_max||'.';
                          end if;
                        end if;
                      end if;
                    end if;
                  exception when others then
                    x_err := x_err||'|El campo '||x_tit||' no es un número válido.';
                  end;
                elsif (g_columnas(i).tipo_de_dato='FEC') then                                                                           -- fec
                  begin
                    tmp_fec := to_date(x_val,'dd/mm/yyyy');
                  exception when others then
                    x_err := x_err||'|El campo '||x_tit||' no es una fecha válida.';
                  end;
                elsif  (g_columnas(i).tipo_de_dato='HORA') then                                                                         -- hora
                  begin
                    tmp_fec := to_date(x_val,'hh24:mi');
                  exception when others then
                    x_err := x_err||'|El campo '||x_tit||' no es una hora válida.';
                  end;
                elsif (g_columnas(i).tipo_de_dato='RAD'
                       and
                       lower(g_columnas(i).lista_de_valores) not like '%select%'
                       and g_columnas(i).lista_de_valores not like '%'||x_val||'=%') then                                               -- rad
                  x_err := x_err||'|El campo '||x_tit||' no es una selección válida.';
                elsif (g_columnas(i).regexp_validacion is not null and not regexp_like(x_val,g_columnas(i).regexp_validacion)) then       -- regexp
                  x_err := x_err||'|'||g_columnas(i).regexp_mensaje;
                end if;
              end if;
             end if;
            end loop;

            -- segundo: si no hubo error, se validan los campos unicos
            if (x_err is null) then
              declare
                u_sql varchar2(2000);
                u_txt char(1);
                u_col int;
                u_tit varchar2(100);
                u_qty int;
                u_typ varchar2(5);
                u_val varchar2(2000);
              begin
                for unicos in (
                  select rownum rnum, trim(regexp_substr(g_pagina.campos_unicos,'[^,]+',1,level)) unico
                  from dual connect by level <= length(g_pagina.campos_unicos)-length(replace(g_pagina.campos_unicos,','))+1
                ) loop
                  -- contar a ver si existe
                  u_sql := null;
                  u_txt := null;
                  u_col := null;
                  u_tit := null;
                  u_qty := null;
                  u_typ := null;
                  u_val := null;
                  for campos in (
                    select upper(trim(regexp_substr(unicos.unico,'[^-]+',1,level))) campo from dual connect by level <= length(unicos.unico)-length(replace(unicos.unico,'-'))+1
                  ) loop
                    if (u_sql like '% where %') then
                      u_sql := u_sql||' and ';
                    else
                      u_sql := u_sql||' where ';
                    end if;
                    -- encontrar el valor
                    u_col := null;
                    u_typ := null;
                    u_tit := initcap(replace(campos.campo,'_',''));
                    u_txt := 'N';
                    for n in 1..g_columnas.count loop
                      if (upper(g_columnas(n).columna) = campos.campo) then
                        u_col := n;
                        u_typ := g_columnas(n).tipo_de_dato;
                        u_tit := g_columnas(n).titulo;
                        if (u_typ in('TXT','MEMO')) then -- en escos campos se busca con collate binary_ai
                          u_txt := 'S';
                        end if;
  --                      exit;
                      end if;
                    end loop;

                    if (g_formulario.exists('TXT_'||campos.campo)) then
                      -- existe en el formulario
                      u_val := g_formulario('TXT_'||campos.campo);
                      if (u_typ='FEC') then
                        u_val := to_char(to_date(u_val,'dd/mm/yyyy'));
                      elsif (u_typ in('NUM','DEC','FLOAT')) then
                        u_val := to_number(replace(u_val,',',''));
                      elsif (u_typ='CHK') then
                        u_val := 'S';
                      else
                        -- es cualquier otra cosa, cojer el valor
                        u_val := g_formulario('TXT_'||campos.campo);
                      end if;
                    else
                      -- no existe en el formulario
                      if (u_col is not null) then
                        -- exists como columna, debe ser un checkbox
                        if (g_columnas(u_col).tipo_de_dato='CHK') then
                          -- es un chk sin marcar (por eso no está en el formulario)
                          u_val := 'N';
                        else
                          -- no esta en el formulario pero existe como columna (parece opcional), dejarlo nulo
                          u_val := null;
                        end if;
                      else
                        -- no existe ni en el formulario, ni como columna
                        -- pues debe ser un parametro opcional o un campo de los que componen el primary key compuesto del maestro (reg->nom->nss por ejemplo)
                        if (g_pagina.id_maestro is null) then
                          -- no es un maestro, pues se quedó sin llenar (esta pagina usa un parametro opcional, ni lo pide ni lo llena)
                          u_val := null;
                        else
                          -- es un maestro, tomar el valor de su tabla maestra
                          declare
                            x_query varchar2(1000);
                            x_err   varchar2(1000);
                          begin
                            select 'select '||campos.campo
                                || ' from ('||consultar||') a'
                                || ' where a.'||campo_id||' = :ID_MAESTRO'
                            into x_query
                            from man_paginas_t p
                            where id_pagina=g_pagina.id_maestro;

                            begin
                              u_val := ejecutar(x_query);
                            exception when others then
                              x_err := sqlerrm;
                              u_val := null;
                            end;
                          end;
                        end if;
                      end if;
                    end if;
                    -- hasta aqui
                    if (u_val is null) then
                      u_sql := u_sql || campos.campo ||' is null ';
                    else
                      if (u_txt='S') then
                        u_sql := u_sql || campos.campo ||' = '''||u_val||''' collate binary_ai ';
                      else
                        u_sql := u_sql || campos.campo ||' = '''||u_val||'''';
                      end if;
                    end if;
                  end loop;

                  -- si está modificando no validar que existe contra si mismo
                  if (m_accion='modificar') then
                    u_sql := u_sql || ' and ' ||g_pagina.campo_id || ' <> :ID_REGISTRO ';
                  end if;
                  u_sql := 'select count(*) from ('||g_pagina.consultar||') u '||u_sql;

                  begin
                    u_qty := ejecutar(u_sql);
                    if (u_qty>0) then
                      x_err := x_err||'|El valor especificado en el campo \"'||u_tit||'\" ya existe.';
                    end if;
                  exception when others then
                    null;
                  end;
                end loop;
              end;
            end if;

            if (x_err is not null) then
              m_mensajes_texto := substr(x_err,2); -- mostrar el error
              m_mensajes_tipo  := 'error';
            else
              -- aqui es que se guarda (agregar o modificar)
              declare
                l_cur  INTEGER;
                l_num  NUMBER;
                m_sp   varchar2(100);
                m_sql  clob;
                m_call clob;

                p_col  int;
                p_txt  varchar2(32000);
                p_val  number(24,6);
                p_fec  date;
                p_arg  varchar2(100);
              begin
                if (m_accion='agregar') then
                  m_sp := g_pagina.agregar;
                else
                  m_sp := g_pagina.modificar;
                end if;

                l_cur := dbms_sql.open_cursor;
                m_sql := 'begin '||m_sp|| '(';

                for proc in (select argument_name from all_arguments where owner||'.'||package_name||'.'||object_name = upper(m_sp) order by sequence)
                loop
                  m_sql := m_sql||':'||proc.argument_name||',';
                end loop;
                m_sql  := substr(m_sql,1,length(m_sql)-1)||'); end;';
                m_call := replace(m_sql,'begin ','begin '||chr(10)||' ');
                m_call := replace(m_call,'); end;',chr(10)||' );'||chr(10)||'end;');
                m_call := replace(m_call,':P_RESULTADO',chr(10)||'  P_RESULTADO');
                dbms_sql.parse(l_cur,m_sql,dbms_sql.native);
                for proc in (
                  select sequence,argument_name,data_type,data_length
                  from all_arguments
                  where owner||'.'||package_name||'.'||object_name = upper(m_sp)
                  and argument_name not like '%_FILENAME' -- los parametros tipo blob llenan el parametro *_filename tambien
                  order by sequence
                ) loop
                  p_col := null;
                  p_txt := null;
                  p_val := null;
                  p_fec := null;
                  p_arg := substr(proc.argument_name,3,99);

                  if (proc.argument_name='P_ID_USUARIO_PROCESA') then
                    dbms_sql.bind_variable(l_cur,':'||proc.argument_name,g_id_usuario_procesa);
                    m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||g_id_usuario_procesa||''',');
                  elsif (proc.data_type in('BLOB')) then
                    -- si es tipo blob, es un archivo cargado y por cada archivo hay uno o dos parametros : el contenido y el nombre del archivo
                    -- ejemplo: en la tabla existe el campo "cedula_frontal blob not null"
                    --          habrá 1 o mas parametros en el metodo que agrega
                    --          1 (requerido)   p_cedula_frontal          in blob,
                    --          2 (opcional)    p_cedula_frontal_filename in varchar2(2000);
                    declare
                      m_llave     varchar2(100);
                      m_filename  varchar2(1000);
                      m_contents  blob;
                    begin
                      m_llave     := replace(proc.argument_name,'P_','TXT_');
                      m_filename  := man_mantenimientos_pkg.sesion_leer          (p_id_sesion,g_pagina.id_pagina,m_llave);
                      m_contents  := man_mantenimientos_pkg.sesion_leer_documento(p_id_sesion,g_pagina.id_pagina,m_llave);
                      -- el blob requerido
                      dbms_sql.bind_variable(l_cur,':'||proc.argument_name,m_contents);
                      m_call := replace(m_call,':'||proc.argument_name||',' ,chr(10)||'  '||rpad(proc.argument_name,40,' ')||'=> '''||proc.data_type||'('||dbms_lob.getlength(m_contents)||' bytes)'',');
                      -- el nombre del archivo opcional (si no lo encuentra y da error lo ignoramos)
                      begin
                        dbms_sql.bind_variable(l_cur,':'||proc.argument_name||'_FILENAME',m_filename);
                        m_call := replace(m_call,':'||proc.argument_name||'_FILENAME,' ,chr(10)||'  '||rpad(proc.argument_name||'_FILENAME',40,' ')||'=> '''||m_filename||''',');
                      exception when others then
                        null; -- ignora este error
                      end;
                    end;
                    --dbms_sql.bind_variable(l_cur,':'||proc.argument_name,sesion_leer_documento(p_id_sesion,g_pagina.id_pagina,replace(proc.argument_name,'P_','TXT_')));
                    --m_call := replace(m_call,':'||proc.argument_name||',' ,chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> ''BLOB'',');
                  elsif (proc.argument_name='P_'||upper(g_pagina.campo_id)) /* P_(pk de la tabla) */ then
                    if (g_formulario.exists('TXT_'||p_arg)) then
                      p_txt := g_formulario('TXT_'||p_arg);
                    else
                      p_txt := sesion_leer(p_id_sesion,g_pagina.id_pagina,'ID_REGISTRO');
                    end if;
                    m_pk_id := p_txt; -- para usarse en la trazabilidad
                    dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                    m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_txt||''',');
                  elsif (proc.argument_name='P_'||upper(g_maestro.campo_id)) then
                    dbms_sql.bind_variable(l_cur,':'||proc.argument_name,sesion_leer(p_id_sesion,g_pagina.id_pagina,'ID_MAESTRO'));
                    m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||sesion_leer(p_id_sesion,g_pagina.id_pagina,'ID_MAESTRO')||''',');
                  elsif (proc.argument_name='P_ID_INVENTARIO') then
                    dbms_sql.bind_variable(l_cur,':'||proc.argument_name,g_id_inventario);
                    m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||g_id_inventario||''',');
                  elsif (proc.argument_name='P_RESULTADO')                 then
                    dbms_sql.bind_variable(l_cur,':'||proc.argument_name,'',2000);
                  else
                    -- tratar de encontrar el numero d la columna
                    p_col := null;
                    for n in 1..g_columnas.count loop
                      if (upper(g_columnas(n).columna) = upper(p_arg)) then
                        p_col := n;
                        exit;
                      end if;
                    end loop;

                    -- cada parametro que pide el procedure debe existir en el formulario de la pagina como un campo TXT_... (o en la tabla de quien eres detalle)
                    if (g_formulario.exists('TXT_'||p_arg)) then
                      -- existe en el formulario, encontrar el numero de la columna
                      p_txt := man_formatear_pkg.htmlDecode(g_formulario('TXT_'||p_arg));
                      if (proc.data_type='DATE') then
                        p_fec := to_date(p_txt,'dd/mm/yyyy');
                        dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_fec);
                        m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_fec||''',');
                      elsif (proc.data_type='NUMBER') then
                        p_val := to_number(replace(p_txt,',',''));
                        dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_val);
                        m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_val||''',');
                      else
                        -- es un checkbox y está en el formulario (lo seleccionaron)
                        if (p_col is not null and g_columnas(p_col).tipo_de_dato='CHK') then
                          p_txt := 'S';
                        end if;
                        -- es cualquier otra cosa, cojer el valor
                        dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                        m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_txt||''',');
                      end if;
                    else
                      -- no existe en el formulario
                      if (p_col is not null) then
                        -- exists como columna, debe ser un checkbox
                        if (g_columnas(p_col).tipo_de_dato='CHK') then
                          -- es un chk sin marcar (por eso no está en el formulario)
                          p_txt := 'N';
                          dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                          m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_txt||''',');
                        elsif (g_columnas(p_col).tipo_de_dato='MCHK') then
                          p_txt := ',';
                          declare
                            s_key varchar2(100);
                            s_val varchar2(100);
                            s_id  varchar2(100);
                          begin
                            s_key := g_formulario.FIRST;
                            WHILE (s_key IS NOT NULL) LOOP
                              s_val := g_formulario(s_key);
                              if (s_key like 'TXT_'||p_arg||'_%') then
                                if (s_val='on') then
                                  s_id  := substr(s_key,length('TXT_'||p_arg)+2,99);                        -- el id encriptado
                                  s_id  := man_mantenimientos_pkg.decrypt(s_id); -- desencriptado
                                  p_txt := p_txt||s_id||',';
                                end if;
                              end if;
                              s_key := g_formulario.NEXT(s_key);
                            END LOOP;
                            dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                            m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '''||p_txt||''',');
                          end;
                        else
                          -- no esta en el formulario pero existe como columna (parece opcional), dejarlo nulo
                          p_txt := null;
                          dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                          m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '||case when p_txt is null then 'null' else ''''||p_txt||'''' end||',');
                        end if;
                      else
                        -- no existe ni en el formulario, ni como columna
                        -- pues debe ser un parametro opcional o un campo de los que componen el primary key compuesto del maestro (reg->nom->nss por ejemplo)
                        if (g_pagina.id_maestro is null) then
                          -- no es un maestro, pues se quedó sin llenar (esta pagina usa un parametro opcional, ni lo pide ni lo llena)
                          p_txt := null;
                        else
                          -- es un maestro, tomar el valor de su tabla maestra
                          declare
                            x_query varchar2(1000);
                            x_err   varchar2(1000);
                          begin
                            select 'select '||substr(proc.argument_name,3,99)
                                || ' from ('||consultar||') a'
                                || ' where a.'||campo_id||' = :ID_MAESTRO'
                            into x_query
                            from man_paginas_t p
                            where id_pagina=g_pagina.id_maestro;

                            begin
                              p_txt := ejecutar(x_query);
                            exception when others then
                              x_err := sqlerrm;
                              p_txt := null;
                            end;
                          end;
                        end if;
                        dbms_sql.bind_variable(l_cur,':'||proc.argument_name,p_txt);
                        m_call := replace(m_call,':'||proc.argument_name||',',chr(10)||'  '||rpad(proc.argument_name,30,' ')||'=> '||case when p_txt is null then 'null' else ''''||p_txt||'''' end||',');
                      end if;
                    end if;
                  end if;
                end loop;

                -- ya va a agregar o modificar, guardar trazabilidad antes (si aplica)
                if (g_trazabilidad='S') then
                  m_traz_id := null;
                  if (m_accion='modificar') then
                    guardar_trazabilidad(
                      p_tiempo             => 'antes',
                      p_id_trazabilidad    => null,
                      p_accion             => m_accion,
                      p_id_registro        => m_pk_id,
                      p_resultado          => m_res_traz
                    );
                    m_traz_id  := to_number(replace(m_res_traz,'OK|',''));  -- quitar ok:
                  end if;
                end if;
                -- hasta aqui guardar trazabilidad antes

                l_num := dbms_sql.execute (l_cur); -- es comentario es para que ignore el hint "value asigned never used"
                dbms_sql.variable_value(l_cur,':P_RESULTADO', m_msg_tmp);
                dbms_sql.close_cursor(l_cur);
                log_acceso(g_id_usuario_procesa,g_pagina.titulo||': '||initcap(m_accion));


               if (upper(m_msg_tmp) like 'OK|%') then
                  m_call := replace(m_call,':P_RESULTADO',chr(10)||'  '||rpad('P_RESULTADO',30,' ')||'=> '''||m_msg_tmp||'''');
                  -- ya va a agregar o modificar, guardar trazabilidad despues (si aplica)
                  if (g_trazabilidad='S') then
                    if (m_accion='agregar') then
                      -- ----------------------------------------------------------------------------------------------------------------
                      -- encontrar el id recien insertado, pero no se puede con returning en los casos de tablas en dblink
                      -- hay que hacer select con los valores que aun estan en el formulario
                      -- ----------------------------------------------------------------------------------------------------------------
                      declare
                        u_sql   varchar2(2000);
                        u_where char(1) := 'N';
/*
                        u_txt char(1);
                        u_col int;
                        u_tit varchar2(100);
                        u_qty int;
                        u_typ varchar2(5);
                        u_val varchar2(2000);
*/
                      begin
                        -- preparar el query para encontrar el id recien insertado
                        u_sql := 'select max('||g_pagina.campo_id||') u from ('||g_pagina.consultar||') u ';
                        if (g_pagina.id_maestro is not null) then
                          u_sql   := u_sql||'where '||g_maestro.campo_id||'=:ID_MAESTRO';
                          u_where := 'S';
                        end if;

                        -- recojer el primer grupo de campos unicos, ej: para sre_ciudadanos_t, campos_unicos diría "tipo_documento-no_documento,id_nss"
                        -- asi que tomaría el primer grupo: tipo_documento-no_documento
                        for unicos in (
                         select * from (
                          select rownum rnum, trim(regexp_substr(g_pagina.campos_unicos,'[^,]+',1,level)) unico from dual connect by level <= length(g_pagina.campos_unicos)-length(replace(g_pagina.campos_unicos,','))+1
                         )
                        )
                        loop
                          -- recojer los campos que componen el primer grupo de campos unicos
                          -- siguiendo el ejemplo anterior, traeria dos registros: tipo_documento y no_documento
                          for campos in (
                            select upper(trim(regexp_substr(unicos.unico,'[^-]+',1,level))) campo from dual connect by level <= length(unicos.unico)-length(replace(unicos.unico,'-'))+1
                          ) loop
                            if g_formulario.exists('TXT_'||upper(campos.campo)) then
                              if (u_where='N') then
                                u_sql   := u_sql||' where ';
                                u_where := 'S';
                              else
                                u_sql := u_sql||' and ';
                              end if;
                              u_sql := u_sql||upper(campos.campo)||'=:TXT_'||upper(campos.campo);
                            end if;
                          end loop; -- el de los campos unicos
                        end loop; -- el del primer grupo de campos unicos

                        m_pk_id := ejecutar(u_sql);
                      exception when others then
                        -- dió error o no pudo encontrar el registro recien insertado
                        -- no es gran cosa, solo es que no guardará trazabilidad
                        m_pk_id := null;
                      end;

                      if (m_pk_id is null) then
                        -- no hacer nada, esto solo sucede cuando no se logra encontrar el registro insertado porque es una pantalla "rara"
                        -- en estos casos es responsabilidad del procedure agregar/modificar/borrar/ejecutar guardar trazabilidad manualmente
                        null;
                      else
                        guardar_trazabilidad(
                          p_tiempo             => 'despues',
                          p_id_trazabilidad    => null,
                          p_accion             => m_accion,
                          p_id_registro        => m_pk_id,
                          p_resultado          => m_res_traz
                        );
                      end if;
                    else
                      guardar_trazabilidad(
                        p_tiempo             => 'despues',
                        p_id_trazabilidad    => m_traz_id,
                        p_accion             => m_accion,
                        p_id_registro        => m_pk_id,
                        p_resultado          => m_res_traz
                      );
                    end if;
                  end if;
                  -- hasta aqui guardar trazabilidad despues

                  m_mensajes_texto := substr(m_msg_tmp,instr(m_msg_tmp,'|')+1,999);       -- del pipe en adelante
                  m_mensajes_tipo  := 'success';

                  -- borrar los archivos cargados
                  delete from inv_db.man_sesiones_t
                  where id_sesion = p_id_sesion
                  and id_pagina = g_pagina.id_pagina
                  and documento is not null;
                  commit;
                  
--                  if (g_pagina.cerrar_al_guardar='S') then
--                    add('<script>window.location.href = "/Bienvenida.aspx?msg='||encrypt(m_mensajes_texto)||'";</script>');
--                  else
                    -- esto es necesario para las paginas tipo E porque se quedan despues de grabar
                    -- pero deben limpiar los campos que son parametros (solo si terminó bien, creo)
                    g_formulario := g_empty_formulario;
--                  end if;
                  
                  --esto es nuevo
                  crear_objetos_permisibles();
                  if (g_pagina.tipo in('A','E') and g_pagina.cerrar_al_guardar='S') then
                    m_accion := 'none';
                  else
                    accion_por_tipo_de_pagina();
                  end if;
                else
                  -- borrar la trazabilidad para que no se quede calimocha (si aplica)
                  if (g_trazabilidad='S') then
                    if (m_traz_id is not null) then
                      delete from inv_db.man_det_trazabilidad_t where id_trazabilidad = m_traz_id;
                      delete from inv_db.man_trazabilidad_t     where id_trazabilidad = m_traz_id;
                      commit;
                    end if;
                  end if;

                  -- terminó ER (error) o EX (excepcion)
                  --leer_registro();
                  m_mensajes_texto := substr(m_msg_tmp,4);
                  m_mensajes_tipo  := 'error';

                  if (upper(m_msg_tmp) like 'EX|%') then
                    insert into inv_db.man_excepciones_t (
                      excepcion,agregado_por,agregado_en
                    ) values (
                      m_call||chr(10)||':P_RESULTADO='||m_mensajes_texto,g_id_usuario_procesa,sysdate
                    ) returning id_excepcion into m_id_error;
                    commit;

                    if (m_mensajes_texto like '%ORA-%') then
                      m_mensajes_texto := substr(m_mensajes_texto,1,instr(m_mensajes_texto,'ORA-')-1);
                    end if;
                    m_mensajes_texto := m_mensajes_texto||' (error#'||m_id_error||')';
                  end if;
                end if;
              exception when others then
                m_sql := m_call||chr(10)||sqlerrm||chr(10)||dbms_utility.format_error_backtrace;
                rollback;

                insert into inv_db.man_excepciones_t (
                  excepcion,agregado_por,agregado_en
                ) values (
                  m_sql,g_id_usuario_procesa,sysdate
                ) returning id_excepcion into m_id_error;
                commit;

                m_mensajes_texto := 'Ha ocurrido una excepción (error#'||m_id_error||')';
                m_mensajes_tipo  := 'error';
              end;
            end if;
          end;
        end if;
      elsif (g_formulario.exists('BTN_BORRAR') or (m_boton_de_accion is not null)) then
        if g_formulario.exists('BTN_BORRAR') then
          if (g_puede_borrar='S') then
            m_sp_ejecutar := g_pagina.borrar;
            m_sp_accion   := 'borrar';
          end if;
        else
          for x in 1..g_acciones.count loop
            if (g_acciones(x).id_accion = m_boton_de_accion) then
              m_sp_ejecutar := g_acciones(x).sentencia;
              m_sp_accion   := g_acciones(x).accion;
            end if;
          end loop;
        end if;

        if (m_sp_ejecutar is null) then
          m_accion         := 'consultar';
          m_mensajes_texto := 'Usted no tiene permiso de ejecutar esta acción.';
          m_mensajes_tipo  := 'error';
        else
          m_mensajes_texto := null;
          m_mensajes_tipo  := null;
          declare
            key varchar2(100);
            val varchar2(100);

            msg varchar2(2000);
            reg_desc varchar2(1000);
            m_conteo int := 0;
            m_existe int := 0;

            m_cant_borrados int := 0;
            m_cant_error    int := 0;
          begin
            key := g_formulario.FIRST;
            WHILE (key IS NOT NULL) LOOP
              if (key like 'CHK_REGISTRO_%') then
                val := substr(key,14);
                begin
                  m_existe := ejecutar('select count(*) from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:P_CUAL','P_CUAL',val);

                  if (m_existe>0) then
                    reg_desc := ejecutar('/*b)'||val||'*/ select '||g_pagina.campo_descripcion||' from ('||g_pagina.consultar||') x where x.'||g_pagina.campo_id||'=:P_REG','P_REG',val);

                    declare
                      m_ro  char(1);
                      m_msg varchar2(500);
                    begin
                      if (g_pagina.condicion_solo_lectura is null) then
                        m_ro  := 'N';
                        m_msg := null;
                      else
                        m_ro := ejecutar('select '||g_pagina.condicion_solo_lectura||' as condicion from ('||g_pagina.consultar||') where '||g_pagina.campo_id||'=:VAL','VAL',val);
                        m_msg := g_pagina.mensaje_solo_lectura;
                      end if;

                      if (m_ro='S') then
                        m_cant_error  := m_cant_error+1;
                        if (m_mensajes_texto is not null) then
                          m_mensajes_texto := m_mensajes_texto||'<br>';
                        end if;
                        if (m_msg is null) then
                          m_mensajes_texto := m_mensajes_texto||reg_desc||': No es posible '||lower(m_sp_accion)||' este registro.';
                        else
                          m_mensajes_texto := m_mensajes_texto||reg_desc||': '||m_msg;
                        end if;
                        m_mensajes_tipo  := 'error';
                      else
                        -- trazabilidad antes
                        if (g_trazabilidad='S') then
                          guardar_trazabilidad(
                            p_tiempo             => 'antes',
                            p_id_trazabilidad    => null,
                            p_accion             => m_sp_accion,
                            p_id_registro        => val,
                            p_resultado          => m_res_traz
                          );
                          m_traz_id  := to_number(replace(m_res_traz,'OK|',''));  -- quitar ok:
                        end if;
                        -- hasta aqui

                        -- determinar si el sp requiere el parametro P_ID_USUARIO_PROCESA para pasarlo o no
                        declare
                          v_conteo int;
                        begin
                          select count(*)
                          into v_conteo
                          from all_arguments
                          where owner='INV_DB'
                          and owner||'.'||package_name||'.'||object_name=upper(m_sp_ejecutar)
                          and argument_name='P_ID_USUARIO_PROCESA';

                          if (v_conteo=0) then
                            -- este método no requiere el parametro p_id_usuario_procesa
                            execute immediate 'begin '||m_sp_ejecutar|| '(:p_reg,:m_res); end;'
                            using in val, out msg;
                          else
                            -- este método requiere el parametro p_id_usuario_procesa
                            execute immediate 'begin '||m_sp_ejecutar|| '(:p_usr,:p_reg,:m_res); end;'
                            using in g_id_usuario_procesa, in val, out msg;
                          end if;
                          log_acceso(g_id_usuario_procesa,g_pagina.titulo||': '||initcap(m_sp_accion));
                        end;

                        if (msg like 'OK|%') then
                          -- trazabilidad despues
                          if (g_trazabilidad='S') then
                            if (m_sp_accion<>'borrar') then
                              guardar_trazabilidad(
                                p_tiempo             => 'despues',
                                p_id_trazabilidad    => m_traz_id,
                                p_accion             => m_sp_accion,
                                p_id_registro        => val,
                                p_resultado          => m_res_traz
                              );
                            end if;
                          end if;
                          -- hasta aqui
                          m_cant_borrados  := m_cant_borrados+1;
                          if (m_mensajes_texto is not null) then
                            m_mensajes_texto := m_mensajes_texto||'<br>';
                          end if;
                          m_mensajes_texto := m_mensajes_texto||reg_desc||': '||substr(msg,4);
                          m_mensajes_tipo  := 'success';
                        else
                          -- borrar la trazabilidad para que no se quede calimocha
                          if (g_trazabilidad='S') then
                            if (m_traz_id is not null) then
                              delete from inv_db.man_det_trazabilidad_t where id_trazabilidad = m_traz_id;
                              delete from inv_db.man_det_trazabilidad_t where id_trazabilidad = m_traz_id;
                              commit;
                            end if;
                          end if;

                          m_cant_error  := m_cant_error+1;
                          if (m_mensajes_texto is not null) then
                            m_mensajes_texto := m_mensajes_texto||'<br>';
                          end if;
                          m_mensajes_texto := m_mensajes_texto||reg_desc||': '||substr(msg,4);
                          m_mensajes_tipo  := 'error';
                        end if;
                        
                        --esto es nuevo
                        crear_objetos_permisibles();

                      end if;  -- no es ro
                    end; -- codigillo de ver si es ro
                    m_conteo := m_conteo+1;
                  else
                    m_mensajes_texto := 'Error al seleccionar el registro. '||val;
                    m_mensajes_tipo  := 'error';
                  end if;
                exception when others then
                  m_mensajes_texto := m_mensajes_texto||'<br>'||reg_desc||': '||sqlerrm;
                end;
              end if;
              key := g_formulario.NEXT(key);
            END LOOP;
            if (m_mensajes_texto is null) then
             if (m_conteo=0) then
              m_mensajes_texto := 'Debe seleccionar al menos un registro.';
              m_mensajes_tipo  := 'warning';
             elsif (m_cant_borrados>0 and m_cant_error=0) then
              m_mensajes_tipo  := 'success';
             elsif (m_cant_borrados>0 and m_cant_error>0) then
              m_mensajes_tipo  := 'warning';
             elsif (m_cant_borrados=0 and m_cant_error>0) then
              m_mensajes_tipo  := 'error';
             end if;
            end if;

            -- determinar en que pagina nos quedaremos
            if (m_cant_borrados = sesion_leer(p_id_sesion, p_id_pagina, 'CANT_REGISTROS')) then
              -- se borraron todos los registros que se ven en pantalla, retroceder una pagina
              declare
                m_pag int := sesion_leer(p_id_sesion, p_id_pagina, 'PAGINADOR');
              begin
                m_pag := m_pag-1;
                if (m_pag<=0) then
                  m_pag := 1;
                end if;
                sesion_guardar(p_id_sesion,g_id_usuario_procesa,g_pagina.id_pagina,'PAGINADOR',m_pag);
              end;
            end if;
            --hasta aqui
            m_accion     := 'consultar';
          end;
        end if;
      else
        if (g_formulario.exists('ACCION')) then
          m_accion := g_formulario('ACCION');
        else
          accion_por_tipo_de_pagina();
        end if;

        -- si cambió de pagina o de detalle dandole a un boton de detalles o de tabs
        declare
          key varchar2(100);
          val varchar2(100);
        begin
          key := g_formulario.first;
          while (key is not null) loop
            if (key like 'BTN_TAB_%' or key like 'BTN_DET_%') then
              val := substr(key,9,999);
              if (key like 'BTN_TAB_%') then
                  sesion_guardar(
                   p_id_sesion,
                   g_id_usuario_procesa,
                   val,                                                                          -- la nueva pagina
                   'ID_MAESTRO',                                                                 -- su maestro es ...
                   sesion_leer(p_id_sesion,g_pagina.id_pagina,'ID_MAESTRO') -- el registro maestro actual
                  );
                p_id_pagina := val;                                                              -- cambio de pagina
              else
                select id_pagina                                                               -- cual tab se verá de primero
                into p_id_pagina                                                               -- cambiar de pagina al primer tab
                from (select p.id_pagina
                      from man_paginas_t p
                      join inv_db.seg_usuarios_permisos_v up on up.id_usuario=g_id_usuario_procesa and up.id_permiso=p.id_permiso_consultar
                      where p.id_maestro is not null and p.id_maestro = g_pagina.id_pagina
                      order by secuencia)
                where rownum=1;

                sesion_guardar(                                         -- guardar el registro clickeado como maestro del primer tab
                  g_id_sesion,
                  g_id_usuario_procesa,
                  p_id_pagina,                                                                 -- la nueva pagina (primer tab)
                  'ID_MAESTRO',                                                                -- su maestro es
                  val                                                                          -- id del registro clickeado
                );
                g_formulario.delete('LOV_MAESTRO');                                              -- si el formulario anterior ya era un detalle, borrar el lov maestro
              end if;
              crear_objetos(p_id_pagina);
              accion_por_tipo_de_pagina();
              exit;
            end if;
            key := g_formulario.next(key);
          end loop;
        end;

        -- si le dió a un boton de ver (o modificar) un registro
        declare
          key varchar2(100);
          val varchar2(100);
        begin
          key := g_formulario.first;
          while (key is not null) loop
            if (key like 'LINK_VER_%' or upper(key)='REG') then
             if (key like 'LINK_VER_%') then
              val := substr(key,10,999);
             else
              val := g_formulario(key);
             end if;
             sesion_guardar(p_id_sesion, p_id_usuario_procesa,g_pagina.id_pagina,'ID_REGISTRO',val);

             if (g_puede_modificar='S') then
               -- de verdad deja ver si este registro en particular es readonly
               if (g_pagina.condicion_solo_lectura is not null) then
                 declare
                   m_res varchar2(1);
                 begin
                   m_res := ejecutar('select '||g_pagina.condicion_solo_lectura||' as condicion from ('||g_pagina.consultar||') where '||g_pagina.campo_id||'=:VAL','VAL',val);
                   if (m_res='S') then
                     -- si el resultado es S es de solo lectura
                     m_accion := 'ver';
                   else
                     m_accion := 'modificar';
                   end if;
                 end;
               else
                 m_accion := 'modificar';
               end if;
             else
               m_accion := 'ver';
             end if;
             exit;
            end if;
            key := g_formulario.next(key);
          end loop;
        end;
      end if;

      if (g_puede_consultar='S') then
        if (m_accion='consultar') then
          -- si se habia seleccionado un registro antes, borrarlo
          delete from man_sesiones_t s
          where s.id_sesion = p_id_sesion
          and s.id_usuario = p_id_usuario_procesa
          and s.id_pagina = p_id_pagina
          and s.llave in('ID_REGISTRO');
          commit;

          consultar();
        elsif (m_accion='imprimir') then
          imprimir();
       elsif (m_accion='reporte') then
          reporte();
        elsif (m_accion='exportar') then
          exportar();
        elsif (m_accion='download') then
          download();
        elsif (m_accion='agregar') then
          -- borrar de la sesion los archvios cargados anteriormente
          delete from man_sesiones_t s
          where s.id_sesion = p_id_sesion
          and s.id_usuario = p_id_usuario_procesa
          and s.id_pagina = p_id_pagina
          and s.documento is not null;

          agregar();
        elsif (m_accion='ver') then
          ver();
        elsif (m_accion='modificar') then
          if (g_puede_modificar='N' or g_pag_solo_lectura='S') then
            ver();
          else
            -- borrar de la sesion los archvios cargados anteriormente
            delete from man_sesiones_t s
            where s.id_sesion = g_id_sesion
            and s.id_usuario = g_id_usuario_procesa
            and s.id_pagina = p_id_pagina
            and s.documento is not null;

            modificar();
          end if;
        elsif (m_accion='ayuda') then
          ayuda();
        elsif (m_accion='graficar') then
          graficar();
        end if;
        if (m_mensajes_texto is not null) then
          add(alert(m_mensajes_texto,m_mensajes_tipo));
        end if;
      else
        if (lower(g_pagina.consultar) like '%:id_inventario%' and g_id_inventario is null) then
          add(alert('Para acceder a este recurso debe ser un usuario registrado para usar un inventario.','error'));
        else
          add(alert('Usted no tiene permisos para acceder a este recurso.','error'));
        end if;
      end if;
    else
      add(alert(m_mensajes_texto,'error'));
    end if;
   else
     add(alert('Usted no tiene permiso para acceder a este recurso.','error'));
   end if;

   p_resultado := g_resultado;
  exception when others then
    p_resultado :=  g_resultado||'<br>'||sqlerrm||'<br>'||dbms_utility.format_error_backtrace;
  end preparar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : reinicia (elimina los valores anteriores) de una sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
  */
  procedure sesion_iniciar(
    p_id_sesion      in man_sesiones_t.id_sesion%type
  ) is
  begin
    delete from man_sesiones_t
    where id_sesion = p_id_sesion;
    commit;
  end sesion_iniciar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : lee el valor de una variable almacenada en una sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable cuyo valor se desea consultar
    * @returns valor de la variable de sesion del usuario logueado en la página actual
  */
  function sesion_leer(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  ) return varchar2 is
    m_valor man_sesiones_t.valor%type;
  begin
    select valor
    into m_valor
    from man_sesiones_t
    where id_sesion = p_id_sesion
    and (p_id_pagina is null or id_pagina=p_id_pagina)
    and UPPER(llave) = UPPER(p_llave);
    return m_valor;
  exception when no_data_found then
    return null;
  end sesion_leer;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : lee el archivo cargado en una variable de sesion de un usuario en una pagina
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable cuyo valor se desea consultar
    * @returns devuelve un blob con el contenido de un archivo cargado en una variable de sesion del usuario logueado en la página actual
  */
  function sesion_leer_documento(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  ) return blob is
    m_documento blob;
  begin
    select documento
    into m_documento
    from man_sesiones_t
    where id_sesion = p_id_sesion
    and (p_id_pagina is null or id_pagina=p_id_pagina)
    and UPPER(llave) = UPPER(p_llave);

    return m_documento;
  exception when others then
    return null;
  end sesion_leer_documento;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Guardar un valor en una variable de sesion del usuario logueado en la página actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_usuario: id del usuario logueado
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
    * @p_valor: valor a guardar en dicha variable
  */
  procedure sesion_guardar(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_usuario     in man_sesiones_t.id_usuario%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type,
    p_valor          in man_sesiones_t.valor%type
  ) is
   m_conteo int;
  begin
    select count(*)
    into m_conteo
    from man_sesiones_t
    where id_sesion = p_id_sesion
    and id_usuario = p_id_usuario
    and (p_id_pagina is null or id_pagina = p_id_pagina)
    and UPPER(llave)=UPPER(p_llave);

    if (m_conteo=0) then
      insert into man_sesiones_t (
        id_sesion, id_usuario, id_pagina, llave, valor
      ) values (
        p_id_sesion, p_id_usuario, p_id_pagina, UPPER(p_llave), p_valor
      );
    else
      update man_sesiones_t
      set valor=p_valor
      where id_sesion = p_id_sesion
      and id_usuario = p_id_usuario
      and (p_id_pagina is null or id_pagina = p_id_pagina)
      and UPPER(llave)=UPPER(p_llave);
    end if;
    commit;
  end sesion_guardar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : guardar un archivo cargado en una variable de sesion del usuario logueado en la pagina actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_usuario: id del usuario logueado
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
    * @p_documento: contenido del archivo cargado
  */
  procedure sesion_guardar_documento(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_usuario     in man_sesiones_t.id_usuario%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type,
    p_filename       in man_sesiones_t.valor%type,
    p_documento      in blob
  ) is
   m_conteo   int;
  begin
    select count(*)
    into m_conteo
    from man_sesiones_t
    where id_sesion = p_id_sesion
    and id_usuario = p_id_usuario
    and (p_id_pagina is null or id_pagina = p_id_pagina)
    and UPPER(llave)=UPPER(p_llave);

    if (m_conteo=0) then
      insert into man_sesiones_t (
        id_sesion, id_usuario, id_pagina, llave, valor, documento
      ) values (
        p_id_sesion, p_id_usuario, p_id_pagina, UPPER(p_llave), p_filename, p_documento
      );
    else
      update man_sesiones_t
      set valor = p_filename,
          documento = p_documento
      where id_sesion = p_id_sesion
      and id_usuario = p_id_usuario
      and (p_id_pagina is null or id_pagina = p_id_pagina)
      and UPPER(llave)=UPPER(p_llave);
    end if;
    commit;
  end sesion_guardar_documento;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : borrar las variables de OTP de la sesión del usuario logueado
    * @p_id_usuario: id_del usuario logueado
  */
  procedure sesion_borrar(
    p_id_usuario      in man_sesiones_t.id_usuario%type
  ) is
  begin
    delete from man_sesiones_t a
    where a.id_usuario = p_id_usuario
    and substr(a.llave,1,4) = 'OTP_';
    commit;
  end sesion_borrar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : elimina el valor de una llave en una sesion del usuario logueado en la pagina actual
    * @p_id_sesion: Id que da acceso a variables de sesión del usuario logueado en la página actual
    * @p_id_pagina: Id de la pagina actual
    * @p_llave: variable de sesion
  */
  procedure sesion_borrar(
    p_id_sesion      in man_sesiones_t.id_sesion%type,
    p_id_pagina      in man_sesiones_t.id_pagina%type,
    p_llave          in man_sesiones_t.llave%type
  ) is
  begin
    delete from man_sesiones_t a
    where a.id_sesion = p_id_sesion
    and (p_id_pagina is null or a.id_pagina = p_id_pagina)
    and upper(a.llave) = upper(p_llave);
    commit;
  end sesion_borrar;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : encriptar un string mediante el algoritmo text_encode
    * p_texto: texto a desencriptar
    * @returns :texto encriptado
  */
  function encrypt(
    p_texto in varchar2
  ) return varchar2 is
  begin
    -- le agregamos 3 caracteres random al inicio y 3 al final
    return utl_encode.text_encode(DBMS_RANDOM.string('X',3)||p_texto||DBMS_RANDOM.string('X',3),'WE8ISO8859P1', UTL_ENCODE.BASE64);
  end encrypt;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : desencriptar un string encriptado con el algoritmo text_encode
    * p_texto: texto a desencriptar
    * @returns :texto encriptado
  */
  function decrypt(
    p_texto in varchar2
  ) return varchar2 is
    m_res varchar2(1000);
  begin
    -- le quitamos 3 caracteres al inicio y 3 al final
    m_res := utl_encode.text_decode(p_texto,'WE8ISO8859P1', UTL_ENCODE.BASE64);
    m_res := substr(m_res,4,999);
    m_res := substr(m_res,1,length(m_res)-3);
    return m_res;
  end decrypt;

end man_mantenimientos_pkg;
