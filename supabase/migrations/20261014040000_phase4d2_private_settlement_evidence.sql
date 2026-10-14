-- Phase 4D2: private settlement evidence storage and immutable metadata.
-- Uploads are admin-initiated evidence records, not proof of provider authenticity.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'settlement-evidence',
  'settlement-evidence',
  false,
  5242880,
  array['text/csv', 'application/json', 'application/pdf', 'application/octet-stream']
)
on conflict (id) do update
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = excluded.allowed_mime_types;

create table public.settlement_evidence (
  id uuid primary key default gen_random_uuid(),
  import_id uuid references public.settlement_imports(id) on delete restrict,
  storage_path text not null unique check (storage_path ~ '^[0-9a-f-]{36}/[a-f0-9]{64}$'),
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (mime_type in ('text/csv', 'application/json', 'application/pdf', 'application/octet-stream')),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  original_filename text not null check (char_length(original_filename) between 1 and 180),
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  retention_until timestamptz not null default (now() + interval '365 days')
);

create index settlement_evidence_import_idx on public.settlement_evidence (import_id, uploaded_at desc);
create index settlement_evidence_retention_idx on public.settlement_evidence (retention_until);

alter table public.settlement_evidence enable row level security;
revoke all on public.settlement_evidence from public, anon, authenticated, service_role;
grant select, insert on public.settlement_evidence to service_role;

create function public.guard_settlement_evidence_immutable()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '23514', message = 'settlement evidence metadata is immutable';
end;
$function$;

revoke all on function public.guard_settlement_evidence_immutable() from public, anon, authenticated, service_role;
create trigger settlement_evidence_immutable
before update or delete on public.settlement_evidence
for each row execute function public.guard_settlement_evidence_immutable();

comment on table public.settlement_evidence is
  'Private, immutable metadata for uploaded settlement evidence. Source SHA-256 proves byte identity only; it does not authenticate a provider or report origin.';
comment on column public.settlement_evidence.retention_until is
  'Policy target only. Automated retention enforcement/deletion remains a separately reviewed operational gate.';


create function public.record_settlement_evidence(
  p_id uuid,
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
begin
  if p_uploaded_by is null or not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_uploaded_by and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'settlement evidence upload requires an admin';
  end if;

  insert into public.settlement_evidence (
    id, storage_path, source_sha256, mime_type, byte_size,
    original_filename, uploaded_by
  ) values (
    p_id, p_storage_path, p_source_sha256, p_mime_type, p_byte_size,
    p_original_filename, p_uploaded_by
  );

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_uploaded_by,
    'settlement.evidence.uploaded',
    'settlement_evidence',
    p_id::text,
    p_request_id,
    jsonb_build_object(
      'source_sha256', p_source_sha256,
      'byte_size', p_byte_size,
      'content_type', p_mime_type
    )
  );

  return p_id;
end;
$function$;

revoke all on function public.record_settlement_evidence(uuid, text, text, text, bigint, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_settlement_evidence(uuid, text, text, text, bigint, text, uuid, uuid)
  to service_role;

comment on function public.record_settlement_evidence(uuid, text, text, text, bigint, text, uuid, uuid) is
  'Atomically records immutable settlement evidence metadata and the completion audit event after the private object upload succeeds.';
