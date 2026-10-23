-- NEXUS V3 · Licencias normales y por categoría independientes
-- REQUISITOS: ejecutar previamente los SQL base licenses_setup.sql,
-- remote_content_setup.sql y el SQL de categorías anterior.
-- Ejecutar solamente en el Supabase de NEXUS-HACK; revisar antes de RUN.
-- NO modifica archivos .3105 ni cifra los patches.
-- Una categoría marcada libre no requiere key, tras publicar los cambios.
-- La IPA que llama a activate_nexus_category_key necesita este SQL.
begin;

create or replace function public.admin_generate_licenses(
    p_quantity integer default 1,
    p_duration_hours integer default null,
    p_label text default null,
    p_capabilities jsonb default '[]'::jsonb,
    p_custom_license_key text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_quantity integer := greatest(1, least(coalesce(p_quantity, 1), 200));
    v_capabilities jsonb := coalesce(p_capabilities, '[]'::jsonb);
    v_duration integer := p_duration_hours;
    v_expires_at timestamptz := null;
    v_keys text[] := array[]::text[];
    v_key text;
    v_custom text := public.normalize_license_key(p_custom_license_key);
    i integer;
begin
    if not public.is_license_admin() then
        raise exception 'Not authorized';
    end if;

    if jsonb_typeof(v_capabilities) <> 'array' then
        raise exception 'Capabilities must be a JSON array';
    end if;

    -- Las keys normales no llevan capacidades; una key de categoría requiere
    -- que el administrador haya marcado exactamente esa categoría «Con key».
    if exists (
        select 1
        from jsonb_array_elements_text(v_capabilities) as capability(value)
        where capability.value <> 'special_assetindexer'
          and not (
            capability.value ~ '^category:[a-z0-9][a-z0-9_-]{0,79}

    if v_duration is not null and v_duration > 0 then
        v_expires_at := now() + make_interval(hours => v_duration);
    end if;

    if v_custom <> '' then
        if v_quantity <> 1 then
            raise exception 'Custom keys can only be created one at a time';
        end if;

        if v_custom ~ '^NEXUS-[0-9]+$' then
            raise exception 'Old numeric key format is disabled';
        end if;

        v_key := null;
        insert into public.licenses (license_key, label, capabilities, expires_at, created_by, status, is_active)
        values (v_custom, nullif(trim(coalesce(p_label, '')), ''), v_capabilities, v_expires_at, auth.uid(), 'available', true)
        on conflict (license_key) do update
        set
            label = excluded.label,
            capabilities = excluded.capabilities,
            expires_at = excluded.expires_at,
            updated_at = now()
        where public.licenses.used_at is null
          and public.licenses.device_id is null
          and public.licenses.activated_at is null
        returning license_key into v_key;

        if v_key is null then
            raise exception 'Custom key already exists and has been used';
        end if;

        v_keys := array_append(v_keys, v_custom);
    else
        for i in 1..v_quantity loop
            loop
                v_key := public.generate_secure_license_key('NEXUS');
                begin
                    insert into public.licenses (license_key, label, capabilities, expires_at, created_by, status, is_active)
                    values (v_key, nullif(trim(coalesce(p_label, '')), ''), v_capabilities, v_expires_at, auth.uid(), 'available', true);
                    v_keys := array_append(v_keys, v_key);
                    exit;
                exception when unique_violation then
                end;
            end loop;
        end loop;
    end if;

    return json_build_object(
        'success', true,
        'message', 'Keys generated',
        'keys', v_keys,
        'expires_at', v_expires_at
    );
end;
$$;

            and exists (
                select 1
                from public.nexus_app_settings settings
                cross join lateral jsonb_array_elements(
                    case when jsonb_typeof(settings.content->'categories') = 'array'
                         then settings.content->'categories' else '[]'::jsonb end
                ) cat
                where settings.id = 'main'
                  and cat->>'id' = split_part(capability.value, ':', 2)
                  and cat->>'content_type' = 'patch'
                  and coalesce((cat->>'requires_key')::boolean, true) = true
            )
          )
    ) then
        raise exception 'Unsupported category: enable key access in NEXUS panel first';
    end if;

    if v_duration is not null and v_duration > 0 then
        v_expires_at := now() + make_interval(hours => v_duration);
    end if;

    if v_custom <> '' then
        if v_quantity <> 1 then
            raise exception 'Custom keys can only be created one at a time';
        end if;

        if v_custom ~ '^NEXUS-[0-9]+$' then
            raise exception 'Old numeric key format is disabled';
        end if;

        v_key := null;
        insert into public.licenses (license_key, label, capabilities, expires_at, created_by, status, is_active)
        values (v_custom, nullif(trim(coalesce(p_label, '')), ''), v_capabilities, v_expires_at, auth.uid(), 'available', true)
        on conflict (license_key) do update
        set
            label = excluded.label,
            capabilities = excluded.capabilities,
            expires_at = excluded.expires_at,
            updated_at = now()
        where public.licenses.used_at is null
          and public.licenses.device_id is null
          and public.licenses.activated_at is null
        returning license_key into v_key;

        if v_key is null then
            raise exception 'Custom key already exists and has been used';
        end if;

        v_keys := array_append(v_keys, v_custom);
    else
        for i in 1..v_quantity loop
            loop
                v_key := public.generate_secure_license_key('NEXUS');
                begin
                    insert into public.licenses (license_key, label, capabilities, expires_at, created_by, status, is_active)
                    values (v_key, nullif(trim(coalesce(p_label, '')), ''), v_capabilities, v_expires_at, auth.uid(), 'available', true);
                    v_keys := array_append(v_keys, v_key);
                    exit;
                exception when unique_violation then
                end;
            end loop;
        end loop;
    end if;

    return json_build_object(
        'success', true,
        'message', 'Keys generated',
        'keys', v_keys,
        'expires_at', v_expires_at
    );
end;
$$;


create or replace function public.activate_license(
    p_license_key text,
    p_device_id text,
    p_device_model text default null,
    p_ios_version text default null,
    p_app_version text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_license public.licenses%rowtype;
    v_key text;
    v_device text := trim(coalesce(p_device_id, ''));
    v_ip text := public.request_ip();
begin
    v_key := public.normalize_license_key(p_license_key);

    if v_key = '' or v_device = '' then
        return json_build_object('success', false, 'message', 'Invalid key', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    if v_key ~ '^NEXUS-[0-9]+$' then
        return json_build_object('success', false, 'message', 'Old numeric keys are disabled', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    select *
    into v_license
    from public.licenses
    where license_key = v_key
    for update;

    if not found then
        return json_build_object('success', false, 'message', 'Invalid key', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    -- Una key de una categoría NO da acceso general al inicio de sesión de NEXUS.
    if exists (
        select 1 from jsonb_array_elements_text(coalesce(v_license.capabilities, '[]'::jsonb)) as cap(value)
        where cap.value like 'category:%'
    ) then
        return json_build_object('success', false, 'message', 'Esta key es de categoría; utiliza una key normal para entrar a NEXUS', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    if v_license.expires_at is not null and v_license.expires_at <= now() then
        update public.licenses
        set status = 'expired', is_active = false, updated_at = now()
        where id = v_license.id;

        return json_build_object('success', false, 'message', 'Key expired', 'capabilities', json_build_array(), 'expires_at', v_license.expires_at);
    end if;

    if v_license.status in ('paused', 'blocked', 'expired') or v_license.is_active = false then
        return json_build_object(
            'success', false,
            'message', public.license_status_message(v_license.status),
            'capabilities', json_build_array(),
            'expires_at', v_license.expires_at
        );
    end if;

    if v_license.status = 'active'
       and v_license.device_id = v_device
       and v_license.is_active = true then
        update public.licenses
        set
            device_model = coalesce(nullif(trim(coalesce(p_device_model, '')), ''), device_model),
            ios_version = coalesce(nullif(trim(coalesce(p_ios_version, '')), ''), ios_version),
            app_version = coalesce(nullif(trim(coalesce(p_app_version, '')), ''), app_version),
            last_ip = coalesce(v_ip, last_ip),
            last_checked_at = now(),
            used_at = coalesce(used_at, now()),
            updated_at = now()
        where id = v_license.id
        returning * into v_license;

        return json_build_object(
            'success', true,
            'message', 'Key verified',
            'capabilities', coalesce(v_license.capabilities, '[]'::jsonb),
            'expires_at', v_license.expires_at
        );
    end if;

    if v_license.status <> 'available'
        or v_license.used_at is not null
        or v_license.device_id is not null
        or v_license.activated_at is not null then
        return json_build_object(
            'success', false,
            'message', 'This key has already been used',
            'capabilities', json_build_array(),
            'expires_at', v_license.expires_at
        );
    end if;

    update public.licenses
    set
        device_id = v_device,
        activated_at = now(),
        used_at = now(),
        device_model = nullif(trim(coalesce(p_device_model, '')), ''),
        ios_version = nullif(trim(coalesce(p_ios_version, '')), ''),
        app_version = nullif(trim(coalesce(p_app_version, '')), ''),
        activation_ip = v_ip,
        last_ip = v_ip,
        last_checked_at = now(),
        status = 'active',
        is_active = true,
        updated_at = now()
    where id = v_license.id
    returning * into v_license;

    return json_build_object(
        'success', true,
        'message', 'Key activated successfully',
        'capabilities', coalesce(v_license.capabilities, '[]'::jsonb),
        'expires_at', v_license.expires_at
    );
end;
$$;


create or replace function public.check_license(
    p_license_key text,
    p_device_id text,
    p_device_model text default null,
    p_ios_version text default null,
    p_app_version text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_license public.licenses%rowtype;
    v_key text;
    v_device text := trim(coalesce(p_device_id, ''));
    v_ip text := public.request_ip();
begin
    v_key := public.normalize_license_key(p_license_key);

    if v_key = '' or v_device = '' then
        return json_build_object('success', false, 'message', 'Invalid key', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    if v_key ~ '^NEXUS-[0-9]+$' then
        return json_build_object('success', false, 'message', 'Old numeric keys are disabled', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    select *
    into v_license
    from public.licenses
    where license_key = v_key
    for update;

    if not found then
        return json_build_object('success', false, 'message', 'Invalid key', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    -- Una key de una categoría NO da acceso general al inicio de sesión de NEXUS.
    if exists (
        select 1 from jsonb_array_elements_text(coalesce(v_license.capabilities, '[]'::jsonb)) as cap(value)
        where cap.value like 'category:%'
    ) then
        return json_build_object('success', false, 'message', 'Esta key es de categoría; utiliza una key normal para entrar a NEXUS', 'capabilities', json_build_array(), 'expires_at', null);
    end if;

    if v_license.expires_at is not null and v_license.expires_at <= now() then
        update public.licenses
        set status = 'expired', is_active = false, updated_at = now()
        where id = v_license.id;

        return json_build_object('success', false, 'message', 'Key expired', 'capabilities', json_build_array(), 'expires_at', v_license.expires_at);
    end if;

    if v_license.status in ('paused', 'blocked', 'expired') or v_license.is_active = false then
        return json_build_object(
            'success', false,
            'message', public.license_status_message(v_license.status),
            'capabilities', json_build_array(),
            'expires_at', v_license.expires_at
        );
    end if;

    if v_license.status <> 'active' or v_license.device_id is null then
        return json_build_object('success', false, 'message', 'Key is not active on this device', 'capabilities', json_build_array(), 'expires_at', v_license.expires_at);
    end if;

    if v_license.device_id <> v_device then
        return json_build_object('success', false, 'message', 'This key is already used on another device', 'capabilities', json_build_array(), 'expires_at', v_license.expires_at);
    end if;

    update public.licenses
    set
        device_model = coalesce(nullif(trim(coalesce(p_device_model, '')), ''), device_model),
        ios_version = coalesce(nullif(trim(coalesce(p_ios_version, '')), ''), ios_version),
        app_version = coalesce(nullif(trim(coalesce(p_app_version, '')), ''), app_version),
        last_ip = coalesce(v_ip, last_ip),
        last_checked_at = now(),
        used_at = coalesce(used_at, now()),
        updated_at = now()
    where id = v_license.id
    returning * into v_license;

    return json_build_object(
        'success', true,
        'message', 'Key verified',
        'capabilities', coalesce(v_license.capabilities, '[]'::jsonb),
        'expires_at', v_license.expires_at
    );
end;
$$;


create or replace function public.activate_nexus_category_key(
    p_license_key text, p_device_id text, p_content_id uuid
) returns json
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_license public.licenses%rowtype;
  v_key text := public.normalize_license_key(p_license_key);
  v_device text := trim(coalesce(p_device_id,''));
  v_category text;
  v_requires_key boolean;
begin
  if v_key = '' or v_device = '' or p_content_id is null then
    return json_build_object('success',false,'message','Key, dispositivo o contenido inválido');
  end if;
  select lower(f.category) into v_category
  from public.remote_content_files f
  where f.id = p_content_id and f.is_active = true and f.deleted_at is null
  limit 1;
  if v_category is null then
    return json_build_object('success',false,'message','Patch no publicado o inexistente');
  end if;

  select coalesce((cat->>'requires_key')::boolean,true) into v_requires_key
  from public.nexus_app_settings settings
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(settings.content->'categories')='array'
         then settings.content->'categories' else '[]'::jsonb end
  ) cat
  where settings.id='main' and lower(cat->>'id')=v_category
    and cat->>'content_type'='patch'
  limit 1;
  if v_requires_key is false then
    return json_build_object('success',false,'message','La categoría está configurada como libre; no necesita key');
  end if;

  select * into v_license from public.licenses
  where license_key = v_key for update;
  if not found then
    return json_build_object('success',false,'message','Key inválida');
  end if;
  if coalesce(v_license.capabilities,'[]'::jsonb) @> jsonb_build_array('category:'||v_category) is false then
    return json_build_object('success',false,'message','La key no corresponde a esta categoría');
  end if;
  if v_license.expires_at is not null and v_license.expires_at <= now() then
    update public.licenses set status='expired',is_active=false,updated_at=now() where id=v_license.id;
    return json_build_object('success',false,'message','Key expirada');
  end if;
  if v_license.is_active is false or v_license.status in ('blocked','paused','expired') then
    return json_build_object('success',false,'message',public.license_status_message(v_license.status));
  end if;
  if v_license.device_id is not null and v_license.device_id <> v_device then
    return json_build_object('success',false,'message','Key utilizada en otro dispositivo');
  end if;
  if v_license.status not in ('available','active') then
    return json_build_object('success',false,'message','La key no está disponible');
  end if;
  update public.licenses set
    device_id=v_device,
    activated_at=coalesce(activated_at,now()),
    used_at=coalesce(used_at,now()),
    status='active',
    is_active=true,
    last_checked_at=now(),
    updated_at=now()
  where id=v_license.id;
  return json_build_object('success',true,'message','Categoría NEXUS desbloqueada');
end;
$$;

revoke all on function public.admin_generate_licenses(integer,integer,text,jsonb,text) from public;
grant execute on function public.admin_generate_licenses(integer,integer,text,jsonb,text) to authenticated;
revoke all on function public.activate_nexus_category_key(text,text,uuid) from public;
grant execute on function public.activate_nexus_category_key(text,text,uuid) to anon, authenticated;
notify pgrst, 'reload schema';

commit;
