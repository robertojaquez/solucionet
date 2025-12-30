create or replace package body inv_db.seg_autenticacion_pkg is
  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Este paquete contiene los métodos necesarios para el manejo de la autenticación de usuarios y la entrada al sistema
  */

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Hashear un texto mediante el algoritmo MD5, compatible con el algoritmo utilizado por el SUIRPLUS
    * @p_password texto a hashear
    * @returns el texto provisto, hasheado mediante el algoritmo MD5
  */
  function md5(
    p_password in varchar2
  ) return varchar2 is
    v_hexadecimal varchar2(32);
    v_hashcrudo varchar2(16);
  begin
    v_hashcrudo := dbms_obfuscation_toolkit.md5(input_string => lower(p_password));
    select lower(rawtohex(v_hashcrudo)) into v_hexadecimal from dual;
    return v_hexadecimal;
  end md5;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Hashear un texto mediante el algoritmo HMAC_SH512
    * @p_id_usuario id del usuario cuyo password se desea hashear, compatible con el algoritmo utilizado por el SUIRPLUS
    * @p_password texto a hashear
    * @returns el texto provisto, hasheado mediante el algoritmo HMAC_SH512
  */
  function hmac(p_id_usuario in varchar2, p_password in varchar2) return varchar2 is
    v_llave varchar2(100);
    v_hash  varchar2(1000);
  begin
    select llave into v_llave from rrhh_db.man_config_t;
    v_hash := sys.DBMS_CRYPTO.MAC(
                src => utl_raw.cast_to_raw(trim(upper(p_id_usuario))||p_password),
                typ => DBMS_CRYPTO.HMAC_SH512,
                key => utl_raw.cast_to_raw(v_llave)
              );

    return v_hash;
  end hmac;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : funcion interna para facilitar la renderización de un ícono del menú
    * @p_icono código del ícono que se desea renderizar, ver https://fonts.google.com/icons?icon.style=Rounded
    * @returns el mismo codigo, envuelto en las etiquetas de estilo neceasrias para su renderización
  */
  function ico(
    p_icono in varchar2
  ) return varchar2 is
  begin
    return case when p_icono is not null then '<img src="/_images/'||p_icono||'.png"/>' else '' end;
  end ico;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Encontrar uno de los inventarios a que tiene permiso el usuario para usarlo como predeterminado al loguearse
    * @p_id_usuario: id del usuario que acaba de loguarse
    * @p_resultado: un string con el id del inventario predeterminado
  */
  procedure obtener_inventario_predeterminado(
    p_id_usuario in varchar2,
    p_resultado out varchar2
  ) is
  begin
    select res
    into p_resultado
    from (
      select 'OK:'||lpad(i.id_inventario,3,'0')||'-'||i.inventario res
      from inv_db.inv_det_inventarios_usuarios_t diu
      join inv_db.inv_inventarios_t i on i.id_inventario=diu.id_inventario and i.estado_registro='A'
      where diu.id_usuario=p_id_usuario
      and diu.estado_registro='A'
      order by diu.id_inventario
    )
    where rownum=1;
  exception when no_data_found then
    p_resultado := 'ER:No tiene inventarios asignados.';
  end obtener_inventario_predeterminado;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Generar el menú de opciones disponibles para un usuario basándonos en sus permisos
    *            Nota: el menú se genera solo una vez al loguearse el usuario para evitar regenerarlo en cada post-back como hace el SUIR
    *            De todas formas la seguridad del sistema responde a los permisos, no a las opciones visibles en el menu
    * @p_id_usuario: id del usuario que acaba de loguarse
    * @p_resultado: un clob con la renderizacíon html del menú que se quedará en una variable de sesión de .net para no volver a ejecutarlo
  */
  procedure generar_menu(
    p_id_usuario in varchar2,
    p_id_inventario int,
    p_resultado out clob
  ) is
  begin
    inv_db.man_mantenimientos_pkg.log_acceso(p_id_usuario,'Entrar al sistema');
    for secciones in (
      select distinct s.secuencia_seccion,s.seccion, s.icono_seccion
      from inv_db.seg_usuarios_menues_v s
      where s.id_usuario = p_id_usuario
      and (
        (p_id_inventario is not null)
        or
        (p_id_inventario is null and s.id_pagina not in(select id_pagina from inv_db.man_paginas_t where lower(consultar) like '%:id_inventario%'))
      )
      order by s.secuencia_seccion
    ) loop
      p_resultado := p_resultado
      || '<div><details>'||chr(10)
      || '<summary><div>'|| ico(secciones.icono_seccion)|| '<span class="menu_item">'||secciones.seccion||'</span></div></summary>'||chr(10);
      for opciones in (
        select distinct secuencia_permiso, permiso, direccion_electronica,icono_permiso
        from seg_usuarios_menues_v
        where seccion = secciones.seccion
        and id_usuario = p_id_usuario
        and (
          (p_id_inventario is not null)
          or
          (p_id_inventario is null and id_pagina not in(select id_pagina from inv_db.man_paginas_t where lower(consultar) like '%:id_inventario%'))
        )
        order by secuencia_permiso
      ) loop
        p_resultado := p_resultado||'<div>'||ico(opciones.icono_permiso)||'<a href='''||opciones.direccion_electronica||'''>'||opciones.permiso||'</a></div>'||chr(10);
      end loop;
      p_resultado := p_resultado||'</details></div>'||chr(10);
    end loop;
    if (p_resultado is not null) then
      p_resultado := '<div id="menu">'||chr(10)||p_resultado||'</div>'||chr(10);  --id=menu
    end if;
  end generar_menu;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : generar tarjetas de bienvenida para el usuario logueado en base a las paginas publicas
    *            estas páginas podrían incluir cada una un SQL que determina si un registro está pendiente
    *            si dicho SQL es ejecutado y trae registros, lo renderizamos en la pantalla de bienvenida
    *            algunas de estas consultas pueden ser costosas, esto no se ejecuta mas de una vez por minuto
    * @p_id_usuario: id del usuario logueado
    * @p_id_inventario: id del inventario que tiene seleccionado
    * @p_resultado: un clob con la renderización HTML de la lista de pendientes de la pagina de bienvenida
  */
  procedure generar_bienvenida(
    p_id_usuario in varchar2,
    p_id_inventario int,
    p_resultado out clob
  ) is
    X INT;
    m_inv_id int;
    m_inv_des varchar2(50);
    m_conteo int;
   begin
     -- contar cuantos inventarios tiene asignados
     select count(*)
     into m_conteo
     from inv_db.inv_det_inventarios_usuarios_t diu
     join inv_db.inv_inventarios_t i on i.id_inventario=diu.id_inventario and i.estado_registro='A'
     where diu.id_usuario = p_id_usuario 
     and diu.estado_registro='A';

     if (p_id_inventario is not null) then
       select id_inventario,inventario
       into m_inv_id, m_inv_des
       from inv_db.inv_inventarios_t
       where id_inventario = p_id_inventario;
     end if;
       
     if (m_inv_id is null or m_inv_des is null) then
        p_resultado := null;
     else
       if (m_conteo>1) then
         p_resultado := '<div style="text-align:center;">'
                      || '<div class="tarjeta">'
                      || '<div class="tarjeta_header">'
                      || '<img class="tarjeta_icon" src="/_images/inventarios.png" />'
                      || '<br/>Inventarios'
                      || '</div>'
                      || '<div style="text-align:left;">';
   
         for inventarios in(
           select i.id_inventario,i.inventario
           from inv_db.inv_det_inventarios_usuarios_t diu
           join inv_db.inv_inventarios_t i on i.id_inventario=diu.id_inventario and i.estado_registro='A'
           where diu.id_usuario = p_id_usuario 
           and diu.estado_registro='A'
           order by i.inventario
         ) loop
           p_resultado := p_resultado
                       || '<input type="radio" id="ID_INVENTARIO_'||inventarios.id_inventario||'" name="ID_INVENTARIO"'
                       || ' value="'||lpad(inventarios.id_inventario,3,'0')||'-'||inventarios.inventario||'"'
                       || case when inventarios.inventario=m_inv_des then ' checked' else '' end
                       || ' onchange="this.form.submit()">'
                       || inventarios.inventario||'<br>';
         end loop;
                    
         p_resultado := p_resultado
                     || '</div>'
                     || '</div>';
       end if;

         /*
         MODO DE USO - hay varias formas:
         1) si quieres un solo titulo colapsable y una lista de cosas, llena pendientes_titulo y pon un sql que traiga las descripciones de las cosas, ej:
            roles sin permisos
            * rol tal 1
            * rol tal 2
         2) si quieres un solo titulo y cantidad, llena pendientes_titulo y pon un sql con count(*) o sum(tal cosa) y que traiga un solo registro, ej:
            roles sin permisos: 2
         3) si quieres múltiples casos/cantidades, deja vacio pendientes_titulo y pon un sql que junte count(*) con su descripcion con group by o union all
            5 trabajadores sin salario
            3 trabajadores con cedula cancelada
            1 subsidio sin aprobar
         */

         select COUNT(*) INTO X
         from inv_db.man_paginas_t p 
         where p.pendientes_sql is not null 
         and ( 
           (p.id_permiso_consultar is null)
           or
           (exists(
            select 1 
            from inv_db.seg_usuarios_permisos_v x 
            where x.id_usuario = p_id_usuario
            and x.id_permiso = p.id_permiso_consultar
           ))
         );
         
         for pendientes in (
           select * from inv_db.man_paginas_t p 
           where p.pendientes_sql is not null 
           and ( 
             (p.id_permiso_consultar is null)
             or
             (exists(
              select 1 
              from inv_db.seg_usuarios_permisos_v x 
              where x.id_usuario = p_id_usuario
              and x.id_permiso = p.id_permiso_consultar
             ))
           )
           order by nvl(p.id_permiso_consultar,0),p.secuencia
         ) loop
            declare
              v_registros int := 0;
              v_cur1 sys_refcursor;
              type t_pendientes is RECORD
              (
                maestro     VARCHAR(1000),
                registro    VARCHAR(1000),
                descripcion VARCHAR(1000)
              );
              v_pendiente t_pendientes;
              m_details clob;
            begin
              if (upper(pendientes.pendientes_sql) like '%:ID_USUARIO%') then
                open v_cur1 for pendientes.pendientes_sql using p_id_usuario;
              else
                open v_cur1 for pendientes.pendientes_sql;
              end if;
              loop
                v_pendiente := null;
                fetch v_cur1 into v_pendiente;
                exit when v_cur1%notfound;
                if (v_pendiente.descripcion is not null) then
                  if (m_details is not null) then 
                    m_details := m_details||'<br>'; 
                  end if;
                  if (v_pendiente.maestro is not null or v_pendiente.registro is not null) then
                    m_details := m_details||'&bull; <a href="/paginas.aspx?pag='||pendientes.id_pagina
                              || case when v_pendiente.maestro is not null then '&mst='||v_pendiente.maestro else '' end
                              || case when v_pendiente.registro is not null then '&reg='||v_pendiente.registro else '' end
                              || '">'||v_pendiente.descripcion||'</a>';
                  else
                    m_details := m_details||'&bull; '||v_pendiente.descripcion;
                  end if;
                end if;
                v_registros := v_registros+1;
              end loop;
              close v_cur1;
              
              -- si es un solo registro y hay un titulo y el query trajo un numero
              if (v_registros=1 and pendientes.pendientes_titulo is not null) then
                declare
                  m_number number(18,6);
                begin
                  m_number  := to_number(substr(m_details,8)); --ignore
                  m_details := m_details||' '||pendientes.pendientes_titulo;
                exception when others then
                  null;
                end;
              end if;
              
    --          if (pendientes.tipo<>'E' or (pendientes.tipo='E' and v_registros>0)) then
              if (v_registros>0) then
                p_resultado := p_resultado
                            || '<div class="tarjeta">'
                            || '<div class="tarjeta_header"'
                            || case 
                               when pendientes.tipo<>'E' then ' onclick="window.location.href=''/paginas.aspx?pag='||pendientes.id_pagina||''';"'
                               else ''
                               end
                            || '>'
                            || case when pendientes.icono is not null then '<img class="tarjeta_icon" src="/_images/'||pendientes.icono||'.png" />' else '' end
                            || '<br/>'||pendientes.titulo
                            || '</div>'
                            || case 
                               when (v_registros>=1 and pendientes.pendientes_titulo is not null) then '<details class="tarjeta_footer"><summary class="tarjeta_summary">'||pendientes.pendientes_titulo||': '||v_registros||'</summary>' 
                               end
                            || case
                               when (v_registros>=1 or m_details is not null) then '<div class="tarjeta_details">'||m_details||'</div>'
                               end
                            || case 
                               when (v_registros>1 and pendientes.pendientes_titulo is not null) then '</details>' 
                               end
                            || '</div>';
              end if;
            exception when others then
              m_details := '<br/>&bull;Error al determinar pendientes: '||sqlerrm ;
              p_resultado := p_resultado
                          || '<div class="tarjeta">'
                          || '<div class="tarjeta_header"'
                          || case 
                             when pendientes.tipo<>'E' then ' onclick="window.location.href=''/paginas.aspx?pag='||pendientes.id_pagina||''';"'
                             else ''
                             end
                          || '>'
                          || case when pendientes.icono is not null then '<img class="tarjeta_icon" src="/_images/'||pendientes.icono||'.png" />' else '' end
                          || '<br/>'||pendientes.titulo
                          || '</div>'
                          || case 
                             when (v_registros>=1 and pendientes.pendientes_titulo is not null) then '<details class="tarjeta_footer"><summary class="tarjeta_summary">'||pendientes.pendientes_titulo||': '||v_registros||'</summary>' 
                             end
                          || case
                             when (v_registros>=1 or m_details is not null) then '<div class="tarjeta_details">'||m_details||'</div>'
                             end
                          || case 
                             when (v_registros>1 and pendientes.pendientes_titulo is not null) then '</details>' 
                             end
                          || '</div>';
            end; 
         end loop;
         p_resultado := p_resultado||'</div>';
       end if;
  end generar_bienvenida;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Contar la cantidad de mensajes sin leer en el buzon de mensajes del usuario logueado
    * @p_id_usuario: id del usuario logueado
    * @p_resultado: Cantidad de mensajes sin leer en el buzon del usuario
  */
  procedure contar_mensajes_pendientes(
    p_id_usuario                     in  varchar2,
    p_resultado                      out number
  ) is
  begin
    select count(*)
    into p_resultado
    from inv_db.seg_buzon_mensajes_t m
    where m.id_usuario = p_id_usuario
    and m.leido = 'N';
  exception when others then
    p_resultado := 0;
  end contar_mensajes_pendientes;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : determina si un usuario tiene un permiso
    * @p_id_usuario: id del usuario logueado
    * @p_id_permiso: id del permiso que se desea verificar si el usuario lo tiene asignado en cualesquiera de sus roles
    *                nota: no se asignan permisos directos, solo a travez de roles
    *                para el rol administrador todos los permisos, actuales y futuros, devuelven S, sin necesidad de asignarlos
    * @returns S/N indicando si el usuario especificado tiene el permiso especificado
  */
  function tiene_permiso(
    p_id_usuario in inv_db.seg_usuarios_v.id_usuario%type,
    p_id_permiso in inv_db.seg_permisos_t.id_permiso%type
  ) return varchar2 is
    v_conteo number;
  begin
    select count(*)
    into v_conteo
    from inv_db.seg_usuarios_v u
    join inv_db.seg_det_roles_usuarios_t dru on dru.id_usuario=u.id_usuario and dru.administrador='A' and dru.estado_registro='A'
    where u.id_usuario=p_id_usuario
    and u.estado_registro='A';

    if (v_conteo>0) then
      -- es administrador, tiene todos los permisos
      return 'S';
    else
      select count(*)
      into v_conteo
      from inv_db.seg_usuarios_v u
      join inv_db.seg_det_roles_usuarios_t dru on dru.id_usuario=u.id_usuario and dru.administrador='N' and dru.estado_registro='A'
      join inv_db.seg_det_permisos_roles_t dpr on dpr.id_rol=dru.id_rol and dpr.estado_registro='A' and dpr.id_permiso=p_id_permiso
      join inv_db.seg_roles_t r                on r.id_rol=dru.id_rol and r.estado_registro='A'
      join inv_db.seg_permisos_t p             on p.id_permiso=dpr.id_permiso and p.estado_registro='A'
      where u.id_usuario=p_id_usuario
      and u.estado_registro='A';

      return case when v_conteo>0 then 'S' else 'N' end;
    end if;
  end tiene_permiso;

  /**
    * Autor    : Roberto Jaquez & Fausto Montero
    * Fecha    : 21/10/2024
    * Objetivo : Inserta un registro en la tabla html_mail_t del SUIR para que sea enviado por correo
    * @p_sender: Dirección de correo de quien envía el mensaje, se sobre-escribe automáticamente a noreply@... en producción
    * @p_recipient: Dirección de correo de quien recibirá en mensaje
    * @p_subject: Asunto correspondiente al email que se enviará
    * @p_message: Texto del mensaje a enviar
  */
  procedure enviar_email (
    p_sender      IN VARCHAR2,
    p_recipient   IN LONG,
    p_subject     IN VARCHAR2,
    p_message     varchar2
  ) AS
  BEGIN
      --insertar el registro
      INSERT INTO inv_db.html_mail_t (id,
                                        create_date,
                                        sender,
                                        recipient,
                                        subject,
                                        MESSAGE,
                                        MESSAGE_TYPE)
           VALUES (inv_db.html_mail_seq.NEXTVAL,
                   SYSDATE,
                   p_sender,
                   p_recipient,
                   p_subject,
                   p_message,
                   'H');

          COMMIT;
  END enviar_email;
  
  

end seg_autenticacion_pkg;
