-- NEXUS v2: activar una CATEGORIA COMPLETA con una key + contrasena.
-- Ejecutar en el Supabase exclusivo de NEXUS-HACK, DESPUES de:
--   supabase/licenses_setup.sql, supabase/remote_content_setup.sql,
--   supabase/secure_patch_keys_setup.sql
-- No ejecutarlo en GREEG, Glizzy, Software Ch3at, GLOBAL IOS ni SEN$I MARK.
-- Este SQL NO cifra archivos ni impide copiar bytes que ya fueron descargados.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.nexus_category_passwords (
  category_id text primary key,
  password_hash text not null,
  changed_at timestamptz not null default now()
);

alter table public.nexus_category_passwords enable row level security;
revoke all on public.nexus_category_passwords from anon, authenticated;

-- Contraseñas recibidas únicamente por RPC de administrador, nunca en JS, manifiesto o Storage.
create or replace function public.admin_set_nexus_category_password(
  p_category_id text, p_password text
) returns json
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_category text := lower(trim(coalesce(p_category_id, '')));
begin
  if not public.is_license_admin() then
    raise exception 'No autorizado';
  end if;
  if v_category !~ '^[a-z0-9][a-z0-9_-]{0,79}$' then
    raise exception 'ID de categoria invalido';
  end if;
  if char_length(coalesce(p_password, '')) < 12 or char_length(p_password) > 128 then
    raise exception 'Contraseña: entre 12 y 128 caracteres';
  end if;

  insert into public.nexus_category_passwords(category_id, password_hash)
  values (v_category, extensions.crypt(p_password, extensions.gen_salt('bf', 12)))
  on conflict (category_id) do update set
    password_hash = excluded.password_hash,
    changed_at = now();

  return json_build_object('success',true,'message','Contraseña guardada para la categoría ' || v_category);
end;
$$;

revoke all on function public.admin_set_nexus_category_password(text,text) from public;
grant execute on function public.admin_set_nexus_category_password(text,text) to authenticated;

-- Cada licencia nueva lleva capability "category:<category_id>" (o all_content).
-- Se recibe un UUID de contenido para verificar en el servidor su categoria real:
-- NO se confia en una categoria enviada por el cliente.
create or replace function public.activate_nexus_category(
  p_license_key text,
  p_device_id text,
  p_content_id uuid,
  p_password text default ''
) returns json
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_license public.licenses%rowtype;
  v_password public.nexus_category_passwords%rowtype;
  v_key text := public.normalize_license_key(p_license_key);
  v_device text := trim(coalesce(p_device_id, ''));
  v_category text;
  v_capability text;
begin
  if v_key = '' or v_device = '' or p_content_id is null then
    return json_build_object('success',false,'message','Key, dispositivo o archivo inválido');
  end if;

  select lower(f.category) into v_category
  from public.remote_content_files f
  where f.id = p_content_id and f.is_active = true and f.deleted_at is null;

  if v_category is null then
    return json_build_object('success',false,'message','Categoría de patch inexistente');
  end if;

  v_capability := 'category:' || v_category;
  select * into v_password
  from public.nexus_category_passwords
  where category_id = v_category;

  -- Fail closed: ninguna categoria se desbloquea hasta definir su contrasena.
  if not found then
    return json_build_object('success',false,'message',
      'El administrador debe configurar la contraseña de esta categoría');
  end if;
  if char_length(coalesce(p_password,'')) < 12
     or extensions.crypt(coalesce(p_password,''),v_password.password_hash) <> v_password.password_hash then
    return json_build_object('success',false,'message','Contraseña de categoría incorrecta');
  end if;

  select * into v_license from public.licenses
  where license_key = v_key for update;

  if not found then
    return json_build_object('success',false,'message','Key inválida');
  end if;
  if v_license.expires_at is not null and v_license.expires_at <= now() then
    update public.licenses set status='expired', is_active=false, updated_at=now()
    where id=v_license.id;
    return json_build_object('success',false,'message','Key expirada');
  end if;
  if v_license.status in ('blocked','paused','expired') or v_license.is_active=false then
    return json_build_object('success',false,'message',public.license_status_message(v_license.status));
  end if;
  if not (
    coalesce(v_license.capabilities,'[]'::jsonb) @> jsonb_build_array(v_capability)
    or coalesce(v_license.capabilities,'[]'::jsonb) @> '["all_content"]'::jsonb
  ) then
    return json_build_object('success',false,'message','La key no corresponde a esta categoría');
  end if;
  if v_license.device_id is not null and v_license.device_id <> v_device then
    return json_build_object('success',false,'message','La key pertenece a otro dispositivo');
  end if;

  update public.licenses
  set device_id=v_device,
      activated_at=coalesce(activated_at,now()),
      used_at=coalesce(used_at,now()),
      status='active', is_active=true,
      last_checked_at=now(),updated_at=now()
  where id=v_license.id;

  return json_build_object('success',true,'message','Categoría NEXUS desbloqueada');
end;
$$;

revoke all on function public.activate_nexus_category(text,text,uuid,text) from public;
grant execute on function public.activate_nexus_category(text,text,uuid,text) to anon,authenticated;
notify pgrst,'reload schema';
