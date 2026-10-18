-- NEXUS HACK community content backend. Run once in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.nexus_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.nexus_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 48),
  icon text not null default 'square.grid.2x2',
  parent_id uuid references public.nexus_categories(id) on delete set null,
  sort_order integer not null default 0 check (sort_order between 0 and 999),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint nexus_categories_no_self_parent check (parent_id is null or parent_id <> id)
);

create table if not exists public.nexus_posts (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.nexus_categories(id) on delete set null,
  kind text not null default 'announcement' check (kind in ('announcement', 'tutorial', 'gallery')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null default '' check (char_length(body) <= 1800),
  image_url text,
  image_path text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nexus_settings (
  id integer primary key check (id = 1),
  brand_name text not null default 'NEXUS HACK' check (char_length(brand_name) between 1 and 48),
  tagline text not null default 'Comunidad, novedades y guias' check (char_length(tagline) <= 100),
  discord_url text,
  tiktok_url text,
  updated_at timestamptz not null default now()
);

create or replace function public.is_nexus_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.nexus_admins a where a.user_id = (select auth.uid()));
$$;
revoke all on function public.is_nexus_admin() from public;
grant execute on function public.is_nexus_admin() to anon, authenticated;

alter table public.nexus_admins enable row level security;
alter table public.nexus_categories enable row level security;
alter table public.nexus_posts enable row level security;
alter table public.nexus_settings enable row level security;

drop policy if exists "nexus admins read own admin row" on public.nexus_admins;
create policy "nexus admins read own admin row" on public.nexus_admins
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "public reads active nexus categories" on public.nexus_categories;
create policy "public reads active nexus categories" on public.nexus_categories
  for select to anon, authenticated using (is_active or (select public.is_nexus_admin()));
drop policy if exists "nexus admins manage categories" on public.nexus_categories;
create policy "nexus admins manage categories" on public.nexus_categories
  for all to authenticated using ((select public.is_nexus_admin())) with check ((select public.is_nexus_admin()));
drop policy if exists "public reads published nexus posts" on public.nexus_posts;
create policy "public reads published nexus posts" on public.nexus_posts
  for select to anon, authenticated using (is_published or (select public.is_nexus_admin()));
drop policy if exists "nexus admins manage posts" on public.nexus_posts;
create policy "nexus admins manage posts" on public.nexus_posts
  for all to authenticated using ((select public.is_nexus_admin())) with check ((select public.is_nexus_admin()));
drop policy if exists "public reads nexus settings" on public.nexus_settings;
create policy "public reads nexus settings" on public.nexus_settings
  for select to anon, authenticated using (true);
drop policy if exists "nexus admins manage settings" on public.nexus_settings;
create policy "nexus admins manage settings" on public.nexus_settings
  for all to authenticated using ((select public.is_nexus_admin())) with check ((select public.is_nexus_admin()));

grant select on public.nexus_categories, public.nexus_posts, public.nexus_settings to anon, authenticated;
grant insert, update, delete on public.nexus_categories, public.nexus_posts, public.nexus_settings to authenticated;
grant select on public.nexus_admins to authenticated;

insert into public.nexus_settings (id, brand_name, tagline, discord_url)
values (1, 'NEXUS HACK', 'Comunidad, novedades y guias', 'https://discord.gg/9NUBpqNGQ')
on conflict (id) do nothing;

insert into public.nexus_categories (name, icon, sort_order)
select seed.name, seed.icon, seed.sort_order from (values
  ('Categoria 1', 'square.grid.2x2', 1), ('Categoria 2', 'sparkles', 2),
  ('Categoria 3', 'book.closed.fill', 3), ('Categoria 4', 'photo', 4),
  ('Categoria 5', 'person.2.fill', 5)
) as seed(name, icon, sort_order)
where not exists (select 1 from public.nexus_categories);

-- Create this user in Supabase Auth first; then uncomment and set your email.
-- insert into public.nexus_admins (user_id)
-- select id from auth.users where lower(email) = lower('YOUR_ADMIN_EMAIL')
-- on conflict (user_id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('nexus-media', 'nexus-media', true, 4194304, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "public reads nexus media" on storage.objects;
create policy "public reads nexus media" on storage.objects
  for select to anon, authenticated using (bucket_id = 'nexus-media');
drop policy if exists "nexus admins upload media" on storage.objects;
create policy "nexus admins upload media" on storage.objects
  for insert to authenticated with check (bucket_id = 'nexus-media' and (select public.is_nexus_admin()));
drop policy if exists "nexus admins update media" on storage.objects;
create policy "nexus admins update media" on storage.objects
  for update to authenticated using (bucket_id = 'nexus-media' and (select public.is_nexus_admin()))
  with check (bucket_id = 'nexus-media' and (select public.is_nexus_admin()));
drop policy if exists "nexus admins delete media" on storage.objects;
create policy "nexus admins delete media" on storage.objects
  for delete to authenticated using (bucket_id = 'nexus-media' and (select public.is_nexus_admin()));
