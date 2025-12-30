create or replace package body inv_db.man_formatear_pkg is
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el formatear alginos valores de cara al usuario
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : formatea una fecha en formato dd/mm/yyyy
    * @p_fecha fecha que se desea formatear
    * returns string que representa la fecha en formato dd/mm/yyyy
  */
  function y_m_d(
    p_fecha in date
  ) return varchar2 is
  begin
    return to_char(p_fecha,'dd/mm/yyyy');
  exception when others then
    return p_fecha;
  end y_m_d;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : formatea un string que puede ser una fecha, en diferentes formatos, a fecha en formato dd/mm/yyyy
    * @p_fecha texto que parece una fecha y que se desea llevar a dd/mm/yyyy
    * returns string que representa la fecha en formato dd/mm/yyyy
  */
  function y_m_d (
    p_fecha in varchar2
  ) return varchar2 is
    v_fec date;
  begin
    if (p_fecha is not null) then
      -- ver si está en formato de oracle
      begin
        v_fec := to_date(p_fecha,'dd-mon-yy');
      exception when others then
        -- ver si está en formato oracle yyyy
        begin
          v_fec := to_date(p_fecha,'dd-mon-yyyy');
        exception when others then
          -- ver si está en formato espanol
          begin
            v_fec := to_date(p_fecha,'d/mm/yyyy');
          exception when others then
            -- ver si está en formato control web
            begin
              v_fec := to_date(p_fecha,'dd/mm/yyyy');
            exception when others then
              v_fec := null;
            end;
          end;
        end;
      end;
    end if;
    return to_char(v_fec,'dd/mm/yyyy');
  end y_m_d;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : retorna las descripciones de varios mensaje de error específicoe para un método
    * @p_mensajes codigos de mensajes a devolver, separados por pipes
    * @returns mensajes de error al usuario, separados por <br>
  */
  function mensaje_de_error(
    p_mensajes in varchar2
  ) return varchar2 is
    v_cantidad int := REGEXP_COUNT(p_mensajes, '\|');
    v_res varchar2(1000);
  begin
    if (v_cantidad=0) then
      v_res := p_mensajes;
    elsif (v_cantidad=1) then
      v_res := substr(p_mensajes,2);
    else
      v_res := replace(p_mensajes,'|','<br>');
    end if;
    return v_res;
  end mensaje_de_error;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : retorna la descripcion de un mensaje de error específico para un método
    *            si no existe, lo crea con el texto error desconocido, para que pueda se modificado en el sistema sin tener que
    *            hacer un pase a producción
    * @p_codigo codigo del mensaje a devolver
    * @returns mensaje de error al usuario
  */
  function mensaje(
    p_codigo man_mensajes_t.codigo%type
  )
  return varchar2 is
   -- este pragma es necesario para insertarlo si al hacerle select no existe
   PRAGMA AUTONOMOUS_TRANSACTION;
    v_owner  varchar2 (100);
    v_caller varchar2 (100);
    v_type   varchar2 (100);
    v_line   number;
    v_res    man_mensajes_t.mensaje%type;
  begin
    owa_util.who_called_me (v_owner,v_caller,v_line,v_type);
    begin
      select m.mensaje
      into v_res
      from man_mensajes_t m
      where m.objeto = lower(v_owner||'.'||v_caller)
      and m.codigo = lower(p_codigo);
    exception when no_data_found then
      v_res := 'Mensaje no encontrado: '||p_codigo;
      insert into man_mensajes_t (
        objeto, codigo, mensaje, agregado_por, agregado_en, estado_registro
      ) values (
        lower(v_owner||'.'||v_caller), lower(p_codigo), v_res , 'OPERACIONES', sysdate, 'A'
      );
      commit;
    end;
    return v_res;
  exception when others then
    return 'Error al buscar mensaje '||p_codigo||': '||sqlerrm;
  end mensaje;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : enmascarar el numero de movil de un usuario para no mostrarlo completo al autenticarse por otp
    * @p_movil número de movil a enmascarar
    * @returns número de movil enmascarado
  */
  function enmascarar_movil(
    p_movil in varchar2
  ) return varchar2 is
  begin
    return substr(p_movil,1,2)||rpad('*',length(p_movil)-5,'*')||substr(p_movil,length(p_movil)-2,3);
  end enmascarar_movil;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : enmascarar la direccion de correo de un usuario para no mostrarla completa al autenticarse por otp
    * @p_email direccion de correo a enmascarar
    * @returns direccion de correo enmascarada
  */
  function enmascarar_email(
    p_email in varchar2
  ) return varchar2 is
    v_ant varchar2(100);
    v_des varchar2(100);
  begin
    v_ant := substr(p_email,1,instr(p_email,'@')-1);
    v_des := substr(p_email,instr(p_email,'@')+1,99);

    return substr(v_ant,1,1)||rpad('*',length(v_ant)-2,'*')||substr(v_ant,length(v_ant),1)
        || '@'
        || substr(v_des,1,2)||rpad('*',length(v_des)-4,'*')||substr(v_des,length(v_des)-1,2);
  end enmascarar_email;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : devolver un registro de trazabilidad (cambios a un registro, antes y despues) formateado en html para su visualización
    * @p_accion titulo de la acción que se realizó (agregar, modificar,borrar, etc.)
    * @p_id_trazabilidad id del registro de trazabilidad que se desea renderizar
    * @returns un clob con la renderización html de la trazabilidad de un registro
  */
  function detalle_trazabilidad (
    p_accion in varchar2,
    p_id_trazabilidad in inv_db.man_trazabilidad_t.id_trazabilidad%type
  )
  return clob
  is
    v_res clob;
  begin
    v_res := '<table class=''columna_detalles''>';
    v_res := v_res||'<tr><th style=''width:20%''>Columna</th><th width=''40%''>Antes</th><th width=''40%;''>Después</th></tr>';

    for dets in (
      select *
      from inv_db.man_det_trazabilidad_t
      where id_trazabilidad = p_id_trazabilidad
      order by id_det_trazabilidad
    ) loop
      v_res := v_res
            || '<tr>'
            || '<td>'||replace(dets.columna,'_',' ')||'</td>'
            || '<td>'||replace(replace(dets.antes,',',', '),';','; ')||'</td>'
            || '<td>'||case when nvl(dets.antes,'~') <> nvl(dets.despues,'~') and p_accion not in('agregar','borrar')
                       then '<span class=''diff''>'||replace(replace(dets.despues,',',', '),';','; ')||'</span>'
                       else replace(replace(dets.despues,',',', '),';','; ')
                       end
                     ||'</td>'
            || '</tr>';
    end loop;

    v_res := v_res||'</table>';
    return v_res;
  end detalle_trazabilidad;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir un número en su representación verbal
    * @P_NUMEROENTERO numero que se desea convertir, solo la parte entera porque se implementó así para imprimir cheques y los decimales se ponen numéricamente
    * @returns la representación verbal del numero, ejemplo: 12345 -> Doce Mil Trescientos Cuarente y Cinco
  */
  FUNCTION numero_a_letras(
    P_NUMEROENTERO IN NUMBER
  ) RETURN VARCHAR2 IS
    FUERA_DE_RANGO EXCEPTION;

    N_MILLARES_DE_MILLON NUMBER;
    N_MILLONES           NUMBER;
    N_MILLARES           NUMBER;
    CENTENAS             NUMBER;
    CENTIMOS             NUMBER;
    V_NUMEROENLETRA      VARCHAR2(2000);
    N_ENTERO             NUMBER;
    N_MILLARES_DE_BILLON NUMBER;

    FUNCTION MENOR_MIL(P_NUMEROENTERO IN NUMBER) RETURN VARCHAR2 IS
      FUERA_DE_RANGO EXCEPTION;
      NUMERO_ENTERO  EXCEPTION;

      CENTENAS NUMBER;
      DECENAS  NUMBER;
      UNIDADES NUMBER;

      V_NUMEROENLETRA VARCHAR2(100);
      UNIR            VARCHAR2(2);

    BEGIN
      BEGIN
        IF TRUNC(P_NUMEROENTERO) <> P_NUMEROENTERO THEN
          RAISE NUMERO_ENTERO;
        END IF;

        IF P_NUMEROENTERO < 0
           OR P_NUMEROENTERO > 999 THEN
          RAISE FUERA_DE_RANGO;
        END IF;

        IF P_NUMEROENTERO = 100 THEN
          RETURN('CIEN ');
        ELSIF P_NUMEROENTERO = 0 THEN
          RETURN('CERO ');
        ELSIF P_NUMEROENTERO = 1 THEN
          RETURN('UNO ');
        ELSE
          CENTENAS := TRUNC(P_NUMEROENTERO / 100);
          DECENAS  := TRUNC((P_NUMEROENTERO MOD 100) / 10);
          UNIDADES := P_NUMEROENTERO MOD 10;
          UNIR     := 'Y ';

          -- OBTENIENDO CENTENAS
          IF CENTENAS = 1 THEN
            V_NUMEROENLETRA := 'CIENTO ';
          ELSIF CENTENAS = 2 THEN
            V_NUMEROENLETRA := 'DOSCIENTOS ';
          ELSIF CENTENAS = 3 THEN
            V_NUMEROENLETRA := 'TRESCIENTOS ';
          ELSIF CENTENAS = 4 THEN
            V_NUMEROENLETRA := 'CUATROCIENTOS ';
          ELSIF CENTENAS = 5 THEN
            V_NUMEROENLETRA := 'QUINIENTOS ';
          ELSIF CENTENAS = 6 THEN
            V_NUMEROENLETRA := 'SEISCIENTOS ';
          ELSIF CENTENAS = 7 THEN
            V_NUMEROENLETRA := 'SETECIENTOS ';
          ELSIF CENTENAS = 8 THEN
            V_NUMEROENLETRA := 'OCHOCIENTOS ';
          ELSIF CENTENAS = 9 THEN
            V_NUMEROENLETRA := 'NOVECIENTOS ';
          END IF;

          -- OBTENIENDO DECENAS
          IF DECENAS = 3 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'TREINTA ';
          ELSIF DECENAS = 4 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'CUARENTA ';
          ELSIF DECENAS = 5 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'CINCUENTA ';
          ELSIF DECENAS = 6 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'SESENTA ';
          ELSIF DECENAS = 7 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'SETENTA ';
          ELSIF DECENAS = 8 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'OCHENTA ';
          ELSIF DECENAS = 9 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || 'NOVENTA ';
          ELSIF DECENAS = 1 THEN
            IF UNIDADES < 6 THEN
              IF UNIDADES = 0 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'DIEZ ';
              ELSIF UNIDADES = 1 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'ONCE ';
              ELSIF UNIDADES = 2 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'DOCE ';
              ELSIF UNIDADES = 3 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'TRECE ';
              ELSIF UNIDADES = 4 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'CATORCE ';
              ELSIF UNIDADES = 5 THEN
                V_NUMEROENLETRA := V_NUMEROENLETRA || 'QUINCE ';
              END IF;
              UNIDADES := 0;
            ELSE
              V_NUMEROENLETRA := V_NUMEROENLETRA || 'DIECI';
              UNIR            := NULL;
            END IF;
          ELSIF DECENAS = 2 THEN
            IF UNIDADES = 0 THEN
              V_NUMEROENLETRA := V_NUMEROENLETRA || 'VEINTE ';
            ELSE
              V_NUMEROENLETRA := V_NUMEROENLETRA || 'VEINTI';
            END IF;
            UNIR := NULL;
          ELSIF DECENAS = 0 THEN
            UNIR := NULL;
          END IF;

          -- OBTENIENDO UNIDADES
          IF UNIDADES = 1 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'UNO '; -- decia uno
          ELSIF UNIDADES = 2 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'DOS ';
          ELSIF UNIDADES = 3 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'TRES ';
          ELSIF UNIDADES = 4 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'CUATRO ';
          ELSIF UNIDADES = 5 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'CINCO ';
          ELSIF UNIDADES = 6 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'SEIS ';
          ELSIF UNIDADES = 7 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'SIETE ';
          ELSIF UNIDADES = 8 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'OCHO ';
          ELSIF UNIDADES = 9 THEN
            V_NUMEROENLETRA := V_NUMEROENLETRA || UNIR || 'NUEVE ';
          END IF;
        END IF;
        RETURN(V_NUMEROENLETRA);

      EXCEPTION
        WHEN NUMERO_ENTERO THEN
          RETURN('ERROR: EL NUMERO NO ES ENTERO');
        WHEN FUERA_DE_RANGO THEN
          RETURN('ERROR: NUMERO FUERA DE RANGO');
        WHEN OTHERS THEN
          RAISE;
      END;
    END MENOR_MIL;

  BEGIN
    BEGIN
      IF P_NUMEROENTERO < 0
         OR P_NUMEROENTERO > 999999999999999.99 THEN
        RAISE FUERA_DE_RANGO;
      END IF;

      N_ENTERO := TRUNC(P_NUMEROENTERO);

      N_MILLARES_DE_BILLON := TRUNC(N_ENTERO / 1000000000000);

      N_MILLARES_DE_MILLON := TRUNC(MOD(N_ENTERO, 1000000000000) /
                                    1000000000);

      N_MILLONES := TRUNC(MOD(N_ENTERO, 1000000000) / 1000000);

      N_MILLARES := TRUNC(MOD(N_ENTERO, 1000000) / 1000);

      CENTENAS := MOD(N_ENTERO, 1000);

      CENTIMOS := MOD((ROUND(P_NUMEROENTERO, 2) * 100), 100);

      -- BILLONES DE MILLON
      IF N_MILLARES_DE_BILLON = 1 THEN
        IF N_MILLARES_DE_MILLON = 0
           OR N_MILLARES_DE_BILLON = 1 THEN
          V_NUMEROENLETRA := 'UN BILLON ';
        ELSE
          V_NUMEROENLETRA := 'BILLON ';
        END IF;
      ELSIF N_MILLARES_DE_BILLON > 1 THEN

        V_NUMEROENLETRA := MENOR_MIL(N_MILLARES_DE_BILLON);

        IF N_MILLARES_DE_MILLON = 0 THEN
          V_NUMEROENLETRA := V_NUMEROENLETRA || 'MIL BILLONES ';
        ELSE
          V_NUMEROENLETRA := V_NUMEROENLETRA || 'BILLONES ';
        END IF;

      END IF;

      -- MILLARES DE MILLON

      IF N_MILLARES_DE_MILLON = 1 THEN
        IF N_MILLONES = 0 THEN
          V_NUMEROENLETRA := V_NUMEROENLETRA || ' MIL MILLONES ';
        ELSE
          V_NUMEROENLETRA := V_NUMEROENLETRA || ' MIL ';
        END IF;
      ELSIF N_MILLARES_DE_MILLON > 1 THEN

        V_NUMEROENLETRA := V_NUMEROENLETRA ||
                           MENOR_MIL(N_MILLARES_DE_MILLON);

        IF N_MILLONES = 0 THEN
          V_NUMEROENLETRA := V_NUMEROENLETRA || 'MIL MILLONES ';
        ELSE
          V_NUMEROENLETRA := V_NUMEROENLETRA || 'MIL ';
        END IF;

      END IF;

      -- MILLONES
      IF N_MILLONES = 1
         AND N_MILLARES_DE_MILLON = 0 THEN
        V_NUMEROENLETRA := 'UN MILLON ';
      ELSIF N_MILLONES > 0 THEN
        V_NUMEROENLETRA := V_NUMEROENLETRA ||
                           MENOR_MIL(N_MILLONES) ||
                           'MILLONES ';
      END IF;

      -- MILES
      IF N_MILLARES = 1
         AND N_MILLARES_DE_MILLON = 0
         AND N_MILLONES = 0 THEN
        V_NUMEROENLETRA := 'MIL ';
      ELSIF N_MILLARES > 0 THEN
        V_NUMEROENLETRA := V_NUMEROENLETRA ||
                           MENOR_MIL(N_MILLARES) || 'MIL ';
      END IF;

      -- CENTENAS
      IF CENTENAS > 0
         OR (N_ENTERO = 0 AND CENTIMOS = 0) THEN
        V_NUMEROENLETRA := V_NUMEROENLETRA ||
                           MENOR_MIL(CENTENAS);
      END IF;

      -- ESTA PARTE LA HIZO JAQUEZ PARA QUE LOS MILLONES REDONDOS DIGAN "DE PESOS" Y EL RESTO "PESOS"
      if (n_entero=0) then
        V_NUMEROENLETRA := 'CERO';
      elsif (n_entero=1) then
        V_NUMEROENLETRA := 'UNO';
      end if;

      -- CENTAVOS
      if (centimos<>0) then
      V_NUMEROENLETRA := V_NUMEROENLETRA
                      || ' CON '
                      || trim(to_char(CENTIMOS,'99'))||'/100.';
      end if;

      -- cleanup y formateo
      RETURN upper(substr(V_NUMEROENLETRA,1,1))||lower(substr(V_NUMEROENLETRA,2,999));

    EXCEPTION
      WHEN FUERA_DE_RANGO THEN
        RETURN('ERROR: NUMERO FUERA DE RANGO');
      WHEN OTHERS THEN
        RAISE;
    END;
  END numero_a_letras;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir a CLOB el blob resultante de la carga de un archivo
    * @p_blob blob que se desea convertir
    * @returns data del blob en formato clob
  */
  function clobfromblob(
    p_blob blob
  ) return clob is
      l_clob         clob;
      l_dest_offsset integer := 1;
      l_src_offsset  integer := 1;
      l_lang_context integer := dbms_lob.default_lang_ctx;
      l_warning      integer;
   begin
      if p_blob is null then
         return null;
      end if;
      dbms_lob.createTemporary(lob_loc => l_clob
                              ,cache   => false);

      dbms_lob.converttoclob(dest_lob     => l_clob
                            ,src_blob     => p_blob
                            ,amount       => dbms_lob.lobmaxsize
                            ,dest_offset  => l_dest_offsset
                            ,src_offset   => l_src_offsset
                            ,blob_csid    => dbms_lob.default_csid
                            ,lang_context => l_lang_context
                            ,warning      => l_warning);

      return l_clob;
   end clobfromblob;
   
   /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : convertir a CLOB el blob resultante de la carga de un archivo
    * @p_clob clob que se desea convertir
    * @returns data del clob en formato blob
   */
   function clobtoblob(p_clob CLOB) return BLOB is
     Result BLOB;
     o1 integer;
     o2 integer;
     c integer;
     w integer;
   begin
     o1 := 1;
     o2 := 1;
     c := 0;
     w := 0;
     DBMS_LOB.CreateTemporary(Result, true);
     DBMS_LOB.ConvertToBlob(Result, p_clob, length(p_clob), o1, o2, 0, c, w);
     return(Result);
   end clobtoblob;

   /**
     * Autor    : Roberto Jaquez & Fausto Montero
     * Fecha    : 21/10/2024
     * Objetivo : hace decode de las etiquetas HTML a su representacion ASCII
     * p_texto  : texto que se desea decodificar de html a ascii
     * @returns : texto ascii decodificado
   */
   function htmlDecode(
     p_texto in varchar2
   )
   return varchar2 is
   begin
     return replace(replace(replace(replace(replace(p_texto,'&quot;','"'),'&apos;',''''),'&lt;','<'),'&gt;','>'),'&amp;','&');
   end;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : codifica la comilla simple en dos comillas simples para que la construccion de queries dinamicos no se rompa cuando el usuario envie
    *            filtros con comillas en la data
    * p_texto  : texto que se desea codificar
    * @returns : texto codificado
  */
  function sqlEncode(
    p_texto in varchar2
  )
  return varchar2 is
  begin
    -- remplazar la comilla simple por dos comillas simples
    return replace(p_texto,'''','''''');
  end;
  
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Convierte un blob en su representacion textual en formato base64
    * @p_blob  : blob que se desea codificar
    * @returns : un clob conteniendo la representacion base64 del blob
  */
  FUNCTION base64encode(p_blob IN BLOB)
    RETURN CLOB
  IS
    l_clob CLOB;
    l_step PLS_INTEGER := 12000; -- make sure you set a multiple of 3 not higher than 24573
  BEGIN
    FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_blob) - 1 )/l_step) LOOP
      l_clob := l_clob || UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_blob, l_step, i * l_step + 1)));
    END LOOP;
    RETURN l_clob;
  END;  
  
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/04/2025
    * Objetivo : Dada una plantilla HTML, un SQL y un unico valor, devuelve un mensaje a enviar
    * p_html      plantilla html del mensaje
    * p_sql       sentencia sql que obtiene todos los [campos] que se mensionan en la plantilla
    * p_id_registro id del registro individual a devolver, cada SQL lo pide como parametro :id_registro
    * @returns : la plantilla ya parseada con los valores que devuelve el SQL
  */
  function mail_merge(
    p_html     in clob, 
    p_sql      in clob, 
    p_id_registro in varchar2
  ) return clob is
   	l_colCnt 		      number := 0;
  	l_descTbl 		    sys.dbms_sql.desc_tab;
  	l_columnValue     varchar2(4000);
    l_theCursor       number;
  	l_status		      integer;
    v_html            clob;
  Begin
    -- --------------------------------------------------------------------------- prepare & execute
    l_theCursor := sys.dbms_sql.open_cursor;
    sys.dbms_sql.parse( l_theCursor, p_sql, dbms_sql.native );
    if (lower(p_sql) like '%:id_registro%') then
      sys.dbms_sql.bind_variable( l_theCursor, ':id_registro', p_id_registro );
    end if;
    sys.dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
    For i in 1..l_colCnt Loop
      dbms_sql.define_column(l_theCursor, i, l_columnValue, 32000);
    End loop;
    dbms_output.put_line('cols='||l_colCnt);
    l_status := dbms_sql.execute(l_theCursor); --ignore

    -- --------------------------------------------------------------------------- hacemos el mail merge
    v_html := p_html;
    While (dbms_sql.fetch_rows(l_theCursor) > 0 ) Loop
      For i in 1..l_colCnt Loop
        dbms_sql.column_value(l_theCursor, i, l_columnValue);
        dbms_output.put_line(lower(l_descTbl(i).col_name)||'='||l_columnValue);
        v_html := replace(v_html,'['||lower(l_descTbl(i).col_name)||']',l_columnValue);
        v_html := replace(v_html,'['||upper(l_descTbl(i).col_name)||']',l_columnValue);
      End loop;
   End loop;
   sys.dbms_sql.close_cursor(l_theCursor);

    return v_html;
  End Mail_Merge;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 09/06/2025
    * Objetivo : Dada una plantilla HTML, un SQL y un unico valor, devuelve un mensaje a enviar
      p_modo: modo que construira el objeto tabla o divs
    * p_aligments  alineación de las columnas, si hay tres columnas (ej: codigo,fecha y monto), mandar 3 letras: 'LCR'
    * p_sql       sentencia sql que obtiene todos los [campos] que se mensionan en la plantilla
    * p_id_registro id del registro individual a devolver, cada SQL lo pide como parametro :id_registro
    * @returns : la plantilla ya parseada con los valores que devuelve el SQL
  */
  function sql_to_html(
    p_modo      in varchar2,  -- tabla o divs
    p_sql       in varchar2, 
    p_aligments in varchar2,  --alineación de las columnas, si hay tres columnas (ej: codigo,fecha y monto), mandar 3 letras: 'LCR'
    p_id_registro in varchar2
  ) return clob is
   	l_colCnt 		      number := 0;
  	l_descTbl 		    sys.dbms_sql.desc_tab;
  	l_columnValue     varchar2(4000);
    l_theCursor       number;
  	l_status		      integer;
    v_html            clob;
  Begin
    -- --------------------------------------------------------------------------- prepare & execute
    l_theCursor := sys.dbms_sql.open_cursor;
    sys.dbms_sql.parse( l_theCursor, p_sql, dbms_sql.native );
    if (lower(p_sql) like '%:id_registro%') then
      sys.dbms_sql.bind_variable( l_theCursor, ':id_registro', p_id_registro );
    end if;
    sys.dbms_sql.describe_columns( l_theCursor, l_colCnt, l_descTbl );
    For i in 1..l_colCnt Loop
      dbms_sql.define_column(l_theCursor, i, l_columnValue, 32000);
    End loop;
    dbms_output.put_line('cols='||l_colCnt);
    l_status := dbms_sql.execute(l_theCursor); --ignore

    -- --------------------------------------------------------------------------- hacemos el mail merge
    v_html := '';
    if (lower(p_modo) in('t','table','tabla')) then
      -- tabla
      v_html := '<style>.c {font-size:x-small; padding:3px;border: 1px solid grey;}</style>'
             || '<table style=''border-collapse:collapse;''>'||chr(10)
             || '<tr>'||chr(10);
      For i in 1..l_colCnt Loop
        v_html := v_html||'<th bgcolor=''silver'' class=''c''>'||l_descTbl(i).col_name||'</th>'||chr(10);
      End loop;
      v_html := v_html||'</tr>'||chr(10);
    else
      v_html := '<div>'||chr(10);
    end if;
    
    While (dbms_sql.fetch_rows(l_theCursor) > 0 ) Loop
     if (lower(p_modo) in('t','table','tabla')) then
      v_html := v_html||'<tr>'||chr(10);
      For i in 1..l_colCnt Loop
        dbms_sql.column_value(l_theCursor, i, l_columnValue);
        v_html := v_html||'<td'||case upper(substr(p_aligments,i,1)) when 'C' then ' align=''center''' when 'R' then ' align=''right''' else '' end||' class=''c''>'||l_columnValue||'</td>'||chr(10);
      End loop;
      v_html := v_html||'</tr>'||chr(10);
     else
      v_html := v_html||'<div style=''display:inline-block; margin:3px; padding:3px;border-radius:5px; border:1px solid silver; background-color:silver; font-size:x-small;''>'||chr(10);
      For i in 1..l_colCnt Loop
        dbms_sql.column_value(l_theCursor, i, l_columnValue);
        v_html := v_html||'<b>'||l_descTbl(i).col_name||':</b>&nbsp;'||l_columnValue||case when i<l_colCnt then '<br>' else '' end||chr(10);
      End loop;
      v_html := v_html||'</div>'||chr(10);
     end if;
   End loop;
   sys.dbms_sql.close_cursor(l_theCursor);

   if (lower(p_modo) in('t','table','tabla')) then
     -- tabla
     v_html := v_html||'</table>'||chr(10);
   else
     -- tabla
     v_html := v_html||'</div>'||chr(10);
   end if;

   return v_html;
  End sql_to_html;
  
  procedure enviar_email(
    p_asunto in varchar2, 
    p_mensaje in varchar2, 
    p_destinatario in varchar2
  ) is
    v_id      int; 
    m_usuario varchar2(200);
  begin
    -- si es posible, insertarlo tambien como mensaje al inbox
    begin
      select usuario_dominio
      into m_usuario
      from rrhh_db.rh_colaboradores_t
      where lower(email) = lower(p_destinatario);
        
      insert into inv_db.seg_buzon_mensajes_t (
        id_usuario, asunto, mensaje, enviado_en, leido_en, leido
      ) values (
        m_usuario, p_asunto, p_mensaje, sysdate,null,'N'
      );
    exception when no_data_found then
      null;
    end;

    -- enviar el email
    select inv_db.html_mail_seq.nextval into v_id from dual;

    insert into inv_db.html_mail_t (
      id, subject, message, sender, recipient, create_date, status, message_type, prioridad, encriptado
    ) values (
      v_id, p_asunto, p_mensaje, 'noreply@mail.tss2.gob.do', p_destinatario, sysdate, 'N', 'H', 1, 'N'
    );
    commit;
  end;

end man_formatear_pkg;
