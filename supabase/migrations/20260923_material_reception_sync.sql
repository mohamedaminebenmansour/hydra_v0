-- ===========================================================================
-- Hydra v0 — Supabase migration required by the Material Request + Reception
-- flow and the resilient sync engine. Run once in the Supabase SQL editor.
--
-- Symptoms before this migration (from logcat):
--   * PGRST204 "Could not find the 'owner_status_at' column of 'reports'"
--       -> every reception push fails in _updateTlValidation, the report is
--          marked failed and retried forever.
--   * 42703 "column reports.updated_at does not exist"
--       -> every pull fails in pullRemoteChanges.
--   * the same PGRST204/42703 for reception_photo_url / reception_voice_url /
--     owner_status hits _insertRow for freshly captured reports.
-- ===========================================================================

-- "Material Reception" media URLs (written by SyncService._pushOne uploads,
-- persisted into the row by _insertRow / _updateTlValidation).
alter table public.reports add column if not exists reception_photo_url text;
alter table public.reports add column if not exists reception_voice_url text;

-- Owner workflow columns (checkOwnerUpdates pull + _receptionOwnerPayload).
alter table public.reports
  add column if not exists owner_status text default 'pending';
alter table public.reports add column if not exists owner_status_at timestamptz;

-- Pull watermark (pullRemoteChanges: .gt('updated_at', lastPull)).
alter table public.reports
  add column if not exists updated_at timestamptz default now();

-- Existing rows must carry the watermark too, or the first pull skips them.
update public.reports
   set updated_at = coalesce(updated_at, timestamp)
 where updated_at is null;

-- Keep updated_at current on every UPDATE so the watermark pull actually
-- sees owner decisions and merges from other devices.
create or replace function public.reports_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists reports_touch_updated_at on public.reports;
create trigger reports_touch_updated_at
  before update on public.reports
  for each row
  execute function public.reports_touch_updated_at();
