-- Phase 4D2: independently reviewed binding of private evidence to an imported report.
-- This links custody evidence to normalized import metadata; it does not authenticate
-- the provider origin or enable settlement/fee journal posting.
create table public.settlement_evidence_links (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null unique references public.settlement_evidence(id) on delete restrict,
  import_id uuid not null references public.settlement_imports(id) on delete restrict,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  linked_by uuid not null references auth.users(id) on delete restrict,
  linked_at timestamptz not null default now(),
  request_id uuid not null
);

create index settlement_evidence_links_import_idx
  on public.settlement_evidence_links (import_id, linked_at desc);

alter table public.settlement_evidence_links enable row level security;
revoke all on public.settlement_evidence_links from public, anon, authenticated, service_role;

create function public.guard_settlement_evidence_link_immutable()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'settlement evidence link is immutable';
end;
$function$;
revoke all on function public.guard_settlement_evidence_link_immutable() from public, anon, authenticated, service_role;

create trigger settlement_evidence_links_immutable
before update or delete on public.settlement_evidence_links
for each row execute function public.guard_settlement_evidence_link_immutable();

create function public.link_settlement_evidence(
  p_evidence_id uuid,
  p_import_id uuid,
  p_linked_by uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  evidence_row public.settlement_evidence%rowtype;
  import_row public.settlement_imports%rowtype;
  existing_link public.settlement_evidence_links%rowtype;
  new_link_id uuid;
begin
  if p_evidence_id is null or p_import_id is null
    or p_linked_by is null or p_request_id is null
  then
    raise exception using errcode = '23514', message = 'settlement evidence link metadata failed validation';
  end if;

  select * into evidence_row
  from public.settlement_evidence
  where id = p_evidence_id;
  if evidence_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement evidence was not found';
  end if;

  select * into import_row
  from public.settlement_imports
  where id = p_import_id;
  if import_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement import was not found';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_linked_by and ur.role = 'admin'::public.app_role
  ) or p_linked_by = evidence_row.uploaded_by
    or p_linked_by = import_row.imported_by
  then
    raise exception using errcode = '42501', message = 'settlement evidence linking requires a distinct independent admin';
  end if;

  if evidence_row.source_sha256 <> import_row.source_sha256 then
    raise exception using errcode = '23514', message = 'settlement evidence digest does not match settlement import source digest';
  end if;

  perform pg_advisory_xact_lock(hashtext('settlement-evidence-link:' || p_evidence_id::text));

  select * into existing_link
  from public.settlement_evidence_links
  where evidence_id = p_evidence_id;

  if existing_link.id is not null then
    if existing_link.import_id = p_import_id
      and existing_link.source_sha256 = evidence_row.source_sha256
    then
      return existing_link.id;
    end if;
    raise exception using errcode = '23514', message = 'settlement evidence is already linked to another import';
  end if;

  insert into public.settlement_evidence_links (
    evidence_id, import_id, source_sha256, linked_by, request_id
  ) values (
    p_evidence_id, p_import_id, evidence_row.source_sha256, p_linked_by, p_request_id
  ) returning id into new_link_id;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_linked_by,
    'settlement.evidence.linked',
    'settlement_evidence_link',
    new_link_id::text,
    p_request_id,
    jsonb_build_object(
      'evidence_id', p_evidence_id,
      'import_id', p_import_id,
      'source_sha256', evidence_row.source_sha256
    )
  );

  return new_link_id;
end;
$function$;

revoke all on function public.link_settlement_evidence(uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.link_settlement_evidence(uuid, uuid, uuid, uuid)
  to service_role;

comment on table public.settlement_evidence_links is
  'Append-only binding between private evidence custody and a normalized settlement import, reviewed by an admin independent of both upload and import actors.';
comment on function public.link_settlement_evidence(uuid, uuid, uuid, uuid) is
  'Service-only idempotent evidence-to-import binding; requires digest equality and an independent admin. Does not prove provider origin or authorize financial posting.';
