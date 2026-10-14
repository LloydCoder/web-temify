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
