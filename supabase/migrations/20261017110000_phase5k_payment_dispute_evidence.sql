-- Phase 5K: private dispute evidence upload and digest-bound malware scan attestations.
-- This does not submit evidence to a provider or enable live dispute actions.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-dispute-evidence',
  'payment-dispute-evidence',
  false,
  5242880,
  array['application/pdf', 'image/png', 'image/jpeg', 'text/plain', 'application/octet-stream']
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = excluded.allowed_mime_types;

create table public.payment_dispute_evidence (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  storage_path text not null unique
    check (storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[a-f0-9]{64}$'),
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (mime_type in (
    'application/pdf', 'image/png', 'image/jpeg', 'text/plain', 'application/octet-stream'
  )),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  original_filename text not null check (char_length(original_filename) between 1 and 180),
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default clock_timestamp(),
  retention_until timestamptz not null default (clock_timestamp() + interval '365 days'),
  constraint payment_dispute_evidence_path_matches_identity
    check (storage_path = dispute_id::text || '/' || id::text || '/' || source_sha256),
  constraint payment_dispute_evidence_retention_after_upload
    check (retention_until >= uploaded_at)
);

create index payment_dispute_evidence_dispute_idx
  on public.payment_dispute_evidence (dispute_id, uploaded_at desc, id desc);
create index payment_dispute_evidence_retention_idx
  on public.payment_dispute_evidence (retention_until);

alter table public.payment_dispute_evidence enable row level security;
revoke all on public.payment_dispute_evidence from public, anon, authenticated, service_role;

create function public.reject_payment_dispute_evidence_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'payment dispute evidence metadata is immutable';
end;
$function$;

revoke all on function public.reject_payment_dispute_evidence_mutation() from public, anon, authenticated, service_role;
create trigger payment_dispute_evidence_immutable
before update or delete on public.payment_dispute_evidence
for each row execute function public.reject_payment_dispute_evidence_mutation();

create table public.payment_dispute_evidence_scan_results (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.payment_dispute_evidence(id) on delete restrict,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  verdict text not null check (verdict in ('clean', 'infected', 'error')),
  scanner_name text not null check (char_length(btrim(scanner_name)) between 1 and 120),
  scanner_version text not null check (char_length(btrim(scanner_version)) between 1 and 80),
  signature_updated_at timestamptz not null,
  scanned_at timestamptz not null default clock_timestamp(),
  request_id uuid not null
);

create index payment_dispute_evidence_scan_latest_idx
  on public.payment_dispute_evidence_scan_results (evidence_id, scanned_at desc, id desc);

alter table public.payment_dispute_evidence_scan_results enable row level security;
revoke all on public.payment_dispute_evidence_scan_results from public, anon, authenticated, service_role;

create function public.reject_payment_dispute_evidence_scan_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'payment dispute evidence scan attestations are immutable';
end;
$function$;

revoke all on function public.reject_payment_dispute_evidence_scan_mutation() from public, anon, authenticated, service_role;
create trigger payment_dispute_evidence_scan_results_immutable
before update or delete on public.payment_dispute_evidence_scan_results
for each row execute function public.reject_payment_dispute_evidence_scan_mutation();

create function public.record_payment_dispute_evidence(
  p_id uuid,
  p_dispute_id uuid,
  p_storage_path text,
  p_source_sha256 text,
  p_mime_type text,
  p_byte_size bigint,
  p_original_filename text,
  p_uploaded_by uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  dispute_row public.payment_disputes%rowtype;
begin
  if p_id is null or p_dispute_id is null or p_uploaded_by is null or p_request_id is null
    or p_source_sha256 is null or p_source_sha256 !~ '^[a-f0-9]{64}$'
    or p_mime_type is null or p_mime_type not in (
      'application/pdf', 'image/png', 'image/jpeg', 'text/plain', 'application/octet-stream'
    )
    or p_byte_size is null or p_byte_size not between 1 and 5242880
    or p_original_filename is null or char_length(btrim(p_original_filename)) not between 1 and 180
    or p_storage_path is distinct from p_dispute_id::text || '/' || p_id::text || '/' || p_source_sha256
  then
    raise exception using errcode = '23514', message = 'payment dispute evidence metadata failed validation';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_uploaded_by and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'payment dispute evidence upload requires an admin';
  end if;

  select * into dispute_row
  from public.payment_disputes
  where id = p_dispute_id
  for share;

  if dispute_row.id is null then
    raise exception using errcode = 'P0002', message = 'payment dispute was not found';
  end if;
  if dispute_row.status not in ('open', 'needs_evidence') then
    raise exception using errcode = '55000', message = 'evidence can only be uploaded for an open dispute needing evidence';
  end if;

  insert into public.payment_dispute_evidence (
    id, dispute_id, storage_path, source_sha256, mime_type, byte_size,
    original_filename, uploaded_by
  ) values (
    p_id, p_dispute_id, p_storage_path, p_source_sha256, p_mime_type, p_byte_size,
    btrim(p_original_filename), p_uploaded_by
  );

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_uploaded_by,
    'payment_dispute.evidence.uploaded',
    'payment_dispute_evidence',
    p_id::text,
    p_request_id::text,
    jsonb_build_object(
      'dispute_id', p_dispute_id,
      'source_sha256', p_source_sha256,
      'byte_size', p_byte_size,
      'content_type', p_mime_type
    )
  );

  return p_id;
end;
$function$;

revoke all on function public.record_payment_dispute_evidence(uuid, uuid, text, text, text, bigint, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_payment_dispute_evidence(uuid, uuid, text, text, text, bigint, text, uuid, uuid)
  to service_role;

create function public.record_payment_dispute_evidence_scan_result(
  p_evidence_id uuid,
  p_source_sha256 text,
  p_verdict text,
  p_scanner_name text,
  p_scanner_version text,
  p_signature_updated_at timestamptz,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  evidence_row public.payment_dispute_evidence%rowtype;
  scan_id uuid;
  scan_time timestamptz := clock_timestamp();
begin
  if p_evidence_id is null or p_request_id is null
    or p_source_sha256 is null or p_source_sha256 !~ '^[a-f0-9]{64}$'
    or p_verdict is null or p_verdict not in ('clean', 'infected', 'error')
    or p_scanner_name is null or char_length(btrim(p_scanner_name)) not between 1 and 120
    or p_scanner_version is null or char_length(btrim(p_scanner_version)) not between 1 and 80
    or p_signature_updated_at is null
    or p_signature_updated_at > scan_time + interval '5 minutes'
    or p_signature_updated_at < scan_time - interval '7 days'
  then
    raise exception using errcode = '23514', message = 'payment dispute evidence scan metadata failed validation';
  end if;

  perform pg_advisory_xact_lock(hashtext('payment-dispute-evidence-scan:' || p_evidence_id::text));

  select * into evidence_row
  from public.payment_dispute_evidence
  where id = p_evidence_id
  for share;

  if evidence_row.id is null then
    raise exception using errcode = 'P0002', message = 'payment dispute evidence was not found';
  end if;
  if evidence_row.source_sha256 <> p_source_sha256 then
    raise exception using errcode = '23514', message = 'payment dispute evidence scan digest does not match stored evidence';
  end if;

  insert into public.payment_dispute_evidence_scan_results (
    evidence_id, source_sha256, verdict, scanner_name, scanner_version,
    signature_updated_at, request_id
  ) values (
    p_evidence_id, p_source_sha256, p_verdict, btrim(p_scanner_name),
    btrim(p_scanner_version), p_signature_updated_at, p_request_id
  ) returning id into scan_id;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    null,
    'payment_dispute.evidence.scan_result_recorded',
    'payment_dispute_evidence',
    p_evidence_id::text,
    p_request_id::text,
    jsonb_build_object(
      'scan_result_id', scan_id,
      'source_sha256', p_source_sha256,
      'verdict', p_verdict,
      'scanner_name', btrim(p_scanner_name),
      'scanner_version', btrim(p_scanner_version),
      'signature_updated_at', p_signature_updated_at
    )
  );

  return scan_id;
end;
$function$;

revoke all on function public.record_payment_dispute_evidence_scan_result(uuid, text, text, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_payment_dispute_evidence_scan_result(uuid, text, text, text, text, timestamptz, uuid)
  to service_role;

comment on table public.payment_dispute_evidence is
  'Private immutable dispute evidence metadata. SHA-256 binds stored bytes; it does not establish provider authenticity or submission.';
comment on table public.payment_dispute_evidence_scan_results is
  'Append-only scanner attestations bound to the exact private evidence digest. A missing or stale scan is not clean.';
comment on column public.payment_dispute_evidence.retention_until is
  'Policy target only. Automated dispute-evidence deletion remains disabled until legal retention policy and a dedicated retention worker are approved.';
