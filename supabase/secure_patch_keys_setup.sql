-- NEXUS per-patch access control.
-- Run after licenses_setup.sql and remote_content_setup.sql.
-- Keys are checked server-side and are bound to one device on first use.

alter table public.remote_content_files
    add column if not exists requires_key boolean not null default true,
    add column if not exists price_usd numeric(10,2) not null default 15.00;

create or replace function public.activate_content_license(
    p_license_key text,
    p_device_id text,
    p_content_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_license public.licenses%rowtype;
    v_key text := public.normalize_license_key(p_license_key);
    v_device text := trim(coalesce(p_device_id, ''));
    v_capability text := 'content:' || lower(coalesce(p_content_id::text, ''));
begin
    if v_key = '' or v_device = '' or p_content_id is null then
        return json_build_object('success', false, 'message', 'Key o archivo inválido');
    end if;

    select * into v_license
    from public.licenses
    where license_key = v_key
    for update;

    if not found then
        return json_build_object('success', false, 'message', 'Key inválida');
    end if;

    if v_license.expires_at is not null and v_license.expires_at <= now() then
        update public.licenses set status = 'expired', is_active = false, updated_at = now()
        where id = v_license.id;
        return json_build_object('success', false, 'message', 'La key está expirada');
    end if;

    if v_license.status in ('blocked', 'paused', 'expired') or v_license.is_active = false then
        return json_build_object('success', false, 'message', public.license_status_message(v_license.status));
    end if;

    if not (
        coalesce(v_license.capabilities, '[]'::jsonb) @> jsonb_build_array(v_capability)
        or coalesce(v_license.capabilities, '[]'::jsonb) @> '["all_content"]'::jsonb
    ) then
        return json_build_object('success', false, 'message', 'Esta key no corresponde a este patch');
    end if;

    if v_license.device_id is not null and v_license.device_id <> v_device then
        return json_build_object('success', false, 'message', 'Esta key ya está vinculada a otro dispositivo');
    end if;

    update public.licenses
    set device_id = v_device,
        activated_at = coalesce(activated_at, now()),
        used_at = coalesce(used_at, now()),
        status = 'active',
        is_active = true,
        last_checked_at = now(),
        updated_at = now()
    where id = v_license.id;

    return json_build_object('success', true, 'message', 'Patch desbloqueado');
end;
$$;

revoke all on function public.activate_content_license(text, text, uuid) from public;
grant execute on function public.activate_content_license(text, text, uuid) to anon, authenticated;

-- Make the RPC visible immediately through PostgREST after running this migration.
notify pgrst, 'reload schema';
