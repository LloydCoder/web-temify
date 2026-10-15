-- Phase 4D2: enforce retention for expired, unlinked settlement evidence.
-- Preserve immutable metadata and audit history; only delete private bytes.
create table public.settlement_evidence_retention_jobs (
  evidence_id uuid primary key references public.settlement_evidence(id) on delete restrict,
  storage_path text not null,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  status text not null check (status in ('processing', 'retryable', 'deleted', 'blocked')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  lease_expires_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[a-z0-9_]{1,80}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  last_request_id uuid not null,
  constraint settlement_evidence_retention_job_state_check check (
    (status = 'processing' and lease_expires_at is not null and deleted_at is null)
    or (status = 'retryable' and lease_expires_at is null and deleted_at is null)
    or (status = 'blocked' and lease_expires_at is null and deleted_at is null and attempts >= 5)
    or (status = 'deleted' and lease_expires_at is null and deleted_at is not null)
  )
);

create index settlement_evidence_retention_jobs_retry_idx
  on public.settlement_evidence_retention_jobs (status, lease_expires_at, updated_at);

alter table public.settlement_evidence_retention_jobs enable row level security;
revoke all on public.settlement_evidence_retention_jobs from public, anon, authenticated, service_role;
grant select on public.settlement_evidence_retention_jobs to service_role;

create function public.claim_expired_settlement_evidence(
  p_limit integer,
  p_request_id uuid
)
returns table (
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  byte_size bigint
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  evidence_row public.settlement_evidence%rowtype;
begin
  if p_request_id is null or p_limit is null or p_limit < 1 or p_limit > 25 then
    raise exception using errcode = '22023', message = 'settlement evidence retention claim limit or request id is invalid';
  end if;

  with exhausted_leases as (
    update public.settlement_evidence_retention_jobs as retention_job
    set status = 'blocked', lease_expires_at = null,
        last_error_code = 'worker_lease_expired',
        updated_at = now(), last_request_id = p_request_id
    where retention_job.status = 'processing'
      and retention_job.lease_expires_at <= now()
      and retention_job.attempts >= 5
    returning retention_job.evidence_id, retention_job.source_sha256,
      retention_job.byte_size, retention_job.attempts
  )
  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  )
  select null, 'settlement.evidence.retention_delete_failed',
    'settlement_evidence', expired.evidence_id::text, p_request_id::text,
    jsonb_build_object(
      'source_sha256', expired.source_sha256,
      'byte_size', expired.byte_size,
      'attempt', expired.attempts,
      'status', 'blocked',
      'error_code', 'worker_lease_expired'
    )
  from exhausted_leases as expired;

  for evidence_row in
    select e.*
    from public.settlement_evidence e
    left join public.settlement_evidence_retention_jobs j on j.evidence_id = e.id
    where e.retention_until <= now()
      and not exists (
        select 1 from public.settlement_evidence_links l where l.evidence_id = e.id
      )
      and (
        j.evidence_id is null
        or (j.status = 'retryable' and j.attempts < 5)
        or (j.status = 'processing' and j.lease_expires_at <= now() and j.attempts < 5)
      )
    order by e.retention_until, e.id
    for update of e skip locked
    limit p_limit
  loop
    insert into public.settlement_evidence_retention_jobs (
      evidence_id, storage_path, source_sha256, byte_size, status,
      attempts, lease_expires_at, last_error_code, deleted_at, last_request_id
    ) values (
      evidence_row.id, evidence_row.storage_path, evidence_row.source_sha256,
      evidence_row.byte_size, 'processing', 1, now() + interval '15 minutes',
      null, null, p_request_id
    )
    on conflict on constraint settlement_evidence_retention_jobs_pkey do update
    set storage_path = excluded.storage_path,
        source_sha256 = excluded.source_sha256,
        byte_size = excluded.byte_size,
        status = 'processing',
        attempts = public.settlement_evidence_retention_jobs.attempts + 1,
        lease_expires_at = now() + interval '15 minutes',
        last_error_code = null,
        updated_at = now(),
        last_request_id = excluded.last_request_id
    returning settlement_evidence_retention_jobs.evidence_id,
      settlement_evidence_retention_jobs.storage_path,
      settlement_evidence_retention_jobs.source_sha256,
      settlement_evidence_retention_jobs.byte_size
    into evidence_id, storage_path, source_sha256, byte_size;

    insert into public.audit_events (
      actor_id, action, entity_type, entity_id, request_id, metadata
    ) values (
      null, 'settlement.evidence.retention_delete_requested',
      'settlement_evidence', evidence_row.id::text, p_request_id::text,
      jsonb_build_object(
        'source_sha256', evidence_row.source_sha256,
        'byte_size', evidence_row.byte_size,
        'retention_until', evidence_row.retention_until,
        'attempt', (select j.attempts from public.settlement_evidence_retention_jobs j where j.evidence_id = evidence_row.id)
      )
    );

    return next;
  end loop;
end;
$function$;

create function public.finish_settlement_evidence_retention(
  p_evidence_id uuid,
  p_request_id uuid,
  p_deleted boolean,
  p_error_code text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  job public.settlement_evidence_retention_jobs%rowtype;
  next_status text;
begin
  if p_evidence_id is null or p_request_id is null or p_deleted is null
    or (p_error_code is not null and p_error_code !~ '^[a-z0-9_]{1,80}$')
  then
    raise exception using errcode = '22023', message = 'settlement evidence retention completion metadata is invalid';
  end if;

  select * into job
  from public.settlement_evidence_retention_jobs
  where evidence_id = p_evidence_id
  for update;

  if job.evidence_id is null then
    raise exception using errcode = 'P0002', message = 'settlement evidence retention job was not found';
  end if;
  if job.status <> 'processing' then
    if p_deleted and job.status = 'deleted' then
      return 'deleted';
    end if;
    raise exception using errcode = '55000', message = 'settlement evidence retention job is not processing';
  end if;
  if job.last_request_id <> p_request_id then
    raise exception using errcode = '55000', message = 'settlement evidence retention claim is stale';
  end if;

  if p_deleted then
    next_status := 'deleted';
    update public.settlement_evidence_retention_jobs
    set status = next_status, lease_expires_at = null, last_error_code = null,
        deleted_at = now(), updated_at = now(), last_request_id = p_request_id
    where evidence_id = p_evidence_id;
  else
    next_status := case when job.attempts >= 5 then 'blocked' else 'retryable' end;
    update public.settlement_evidence_retention_jobs
    set status = next_status, lease_expires_at = null,
        last_error_code = coalesce(p_error_code, 'storage_delete_failed'),
        updated_at = now(), last_request_id = p_request_id
    where evidence_id = p_evidence_id;
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    null,
    case when p_deleted then 'settlement.evidence.retention_deleted'
      else 'settlement.evidence.retention_delete_failed' end,
    'settlement_evidence', p_evidence_id::text, p_request_id::text,
    jsonb_build_object(
      'source_sha256', job.source_sha256,
      'byte_size', job.byte_size,
      'attempt', job.attempts,
      'status', next_status,
      'error_code', case when p_deleted then null else coalesce(p_error_code, 'storage_delete_failed') end
    )
  );

  return next_status;
end;
$function$;

revoke all on function public.claim_expired_settlement_evidence(integer, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.finish_settlement_evidence_retention(uuid, uuid, boolean, text)
  from public, anon, authenticated, service_role;
grant execute on function public.claim_expired_settlement_evidence(integer, uuid) to service_role;
grant execute on function public.finish_settlement_evidence_retention(uuid, uuid, boolean, text) to service_role;

comment on table public.settlement_evidence_retention_jobs is
  'Service-only, retryable retention work queue. Successful deletion removes private object bytes only; immutable evidence metadata, links, scan attestations, and audit history are preserved.';
comment on function public.claim_expired_settlement_evidence(integer, uuid) is
  'Claims up to 25 expired, unlinked evidence objects using row locks and 15-minute leases. Linked evidence is retained; callers must delete only the returned private storage path.';
comment on function public.finish_settlement_evidence_retention(uuid, uuid, boolean, text) is
  'Records an idempotent deletion completion or bounded retry. After five failures the job is blocked for operator review; source metadata and audit history remain immutable.';

-- Evidence must not be linked after it expires or after a retention worker has claimed it.
create or replace function public.link_settlement_evidence(
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
  retention_job public.settlement_evidence_retention_jobs%rowtype;
  new_link_id uuid;
begin
  if p_evidence_id is null or p_import_id is null
    or p_linked_by is null or p_request_id is null
  then
    raise exception using errcode = '23514', message = 'settlement evidence link metadata failed validation';
  end if;

  select * into evidence_row
  from public.settlement_evidence
  where id = p_evidence_id
  for update;
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

  perform pg_advisory_xact_lock(hashtext('settlement-evidence-scan:' || p_evidence_id::text));

  if not exists (
    select 1
    from (
      select scan.verdict, scan.source_sha256
      from public.settlement_evidence_scan_results scan
      where scan.evidence_id = p_evidence_id
      order by scan.scanned_at desc, scan.id desc
      limit 1
    ) latest_scan
    where latest_scan.verdict = 'clean'
      and latest_scan.source_sha256 = evidence_row.source_sha256
  ) then
    raise exception using errcode = '23514', message = 'settlement evidence requires a current clean malware scan';
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

  if evidence_row.retention_until <= now() then
    raise exception using errcode = '23514', message = 'expired settlement evidence cannot be linked';
  end if;

  select * into retention_job
  from public.settlement_evidence_retention_jobs
  where evidence_id = p_evidence_id;
  if retention_job.status in ('processing', 'deleted', 'blocked') then
    raise exception using errcode = '23514', message = 'settlement evidence is unavailable for linkage due to retention state';
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

comment on function public.link_settlement_evidence(uuid, uuid, uuid, uuid) is
  'Service-only idempotent evidence-to-import binding; requires digest equality, an unexpired object, a clean malware scan, and an independent admin. Does not prove provider origin or authorize financial posting.';
