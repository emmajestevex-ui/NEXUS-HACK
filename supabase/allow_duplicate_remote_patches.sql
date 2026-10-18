-- Compatibility migration.
-- The maintained remote_content_setup.sql already allows duplicate target paths
-- through p_force_new and owns the content upsert function. This file only
-- repairs the index for installations that used an older setup.
drop index if exists public.remote_content_files_target_path_idx;
drop index if exists public.remote_content_files_target_bundle_path_idx;

create index if not exists remote_content_files_target_bundle_path_idx
on public.remote_content_files (target_bundle, target_path)
where deleted_at is null;
