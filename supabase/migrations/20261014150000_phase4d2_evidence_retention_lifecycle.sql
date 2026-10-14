-- Phase 4D2: enforce evidence retention only after explicit policy activation.
-- The existing 365-day retention_until value is a policy target, not a legal
-- conclusion. Automated deletion is disabled until an admin records a reviewed basis.

create table public.settlement_evidence_retention_settings (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  legal_basis text not null default 'Not enabled: retention policy has not been reviewed',
  updated_by uuid references auth.users(id) on delete restrict,
  updated_at timestamptz not null default now(),
  request_id uuid not null
);

insert into public.settlement_evidence_retention_settings (
  singleton, enabled, legal_basis, updated_by, updated_at, request_id
) values (
  true, false, 'Not enabled: retention policy has not been reviewed',
  null, now(), gen_random_uuid()
)
on conflict (singleton) do nothing;

create table public.settlement_evidence_retention_holds (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.settlement_evidence(id) on delete restrict,
  action text not null check (action in ('placed', 'released')),
  reason text not null check (char_length(btrim(reason)) between 10 and 1000),
  actor_id uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  created_at timestamptz not null default clock_timestamp()
);

create index settlement_evidence_retention_holds_latest_idx
  on public.settlement_evidence_retention_holds (evidence_id, created_at desc, id desc);

create table public.settlement_evidence_retention_jobs (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null unique references public.settlement_evidence(id) on delete restrict,
  storage_path text not null,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  status text not null default 'pending'
    check (status in ('pending', 'claimed', 'deleted', 'failed', 'blocked')),
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  claim_token uuid,
  claimed_by text,
  claimed_at timestamptz,
  scheduled_for timestamptz not null,
  completed_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code in (
    'storage_list_failed', 'storage_delete_failed', 'storage_delete_timeout', 'unknown'
  )),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint settlement_evidence_retention_job_claim_shape check (
    (status = 'claimed' and claim_token is not null and claimed_at is not null and claimed_by is not null)
    or (status <> 'claimed' and claim_token is null and claimed_at is null and claimed_by is null)
  ),
  constraint settlement_evidence_retention_job_completion_shape check (
    (status = 'deleted' and completed_at is not null)
    or (status <> 'deleted' and completed_at is null)
  )
);

create index settlement_evidence_retention_jobs_claim_idx
  on public.settlement_evidence_retention_jobs (status, scheduled_for, created_at);

alter table public.settlement_evidence_retention_settings enable row level security;
alter table public.settlement_evidence_retention_holds enable row level security;
alter table public.settlement_evidence_retention_jobs enable row level security;

revoke all on public.settlement_evidence_retention_settings
  from public, anon, authenticated, service_role;
revoke all on public.settlement_evidence_retention_holds
  from public, anon, authenticated, service_role;
revoke all on public.settlement_evidence_retention_jobs
  from public, anon, authenticated, service_role;

create function public.reject_settlement_evidence_retention_hold_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'settlement evidence retention hold history is immutable';
end;
$function$;

revoke all on function public.reject_settlement_evidence_retention_hold_mutation()
  from public, anon, authenticated, service_role;
create trigger settlement_evidence_retention_holds_immutable
before update or delete on public.settlement_evidence_retention_holds
for each row execute function public.reject_settlement_evidence_retention_hold_mutation();

create function public.get_settlement_evidence_retention_settings()
returns table (
  enabled boolean,
  legal_basis text,
  updated_by uuid,
  updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $function$
  select settings.enabled, settings.legal_basis, settings.updated_by, settings.updated_at
  from public.settlement_evidence_retention_settings settings
  where settings.singleton = true;
$function$;

revoke all on function public.get_settlement_evidence_retention_settings()
  from public, anon, authenticated, service_role;
grant execute on function public.get_settlement_evidence_retention_settings()
  to service_role;

create function public.set_settlement_evidence_retention_enabled(
  p_enabled boolean,
  p_legal_basis text,
  p_actor_id uuid,
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_enabled is null or p_actor_id is null or p_request_id is null
    or p_legal_basis is null
    or char_length(btrim(p_legal_basis)) not between 20 and 1000
  then
    raise exception using errcode = '23514', message = 'settlement evidence retention settings failed validation';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'settlement evidence retention settings require an admin';
  end if;

  update public.settlement_evidence_retention_settings
  set enabled = p_enabled,
      legal_basis = btrim(p_legal_basis),
      updated_by = p_actor_id,
      updated_at = clock_timestamp(),
      request_id = p_request_id
  where singleton = true;

  if not p_enabled then
    update public.settlement_evidence_retention_jobs
    set status = 'pending',
        claim_token = null,
        claimed_by = null,
        claimed_at = null,
        updated_at = clock_timestamp()
    where status = 'claimed';
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_actor_id,
    case when p_enabled
      then 'settlement.evidence.retention_enabled'
      else 'settlement.evidence.retention_disabled'
    end,
    'settlement_evidence_retention',
    'singleton',
    p_request_id::text,
    jsonb_build_object('enabled', p_enabled, 'legal_basis', btrim(p_legal_basis))
  );
end;
$function$;

revoke all on function public.set_settlement_evidence_retention_enabled(boolean, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.set_settlement_evidence_retention_enabled(boolean, text, uuid, uuid)
  to service_role;

create function public.set_settlement_evidence_legal_hold(
  p_evidence_id uuid,
  p_action text,
  p_reason text,
  p_actor_id uuid,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  latest_action text;
  hold_id uuid;
begin
  if p_evidence_id is null or p_request_id is null or p_actor_id is null
    or p_action is null or p_action not in ('placed', 'released')
    or p_reason is null or char_length(btrim(p_reason)) not between 10 and 1000
  then
    raise exception using errcode = '23514', message = 'settlement evidence legal hold metadata failed validation';
  end if;

  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'settlement evidence legal holds require an admin';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('settlement-evidence-retention:' || p_evidence_id::text)
  );

  perform 1 from public.settlement_evidence evidence
  where evidence.id = p_evidence_id
  for share;
  if not found then
    raise exception using errcode = 'P0002', message = 'settlement evidence was not found';
  end if;

  select hold.action into latest_action
  from public.settlement_evidence_retention_holds hold
  where hold.evidence_id = p_evidence_id
  order by hold.created_at desc, hold.id desc
  limit 1;

  if p_action = 'placed' and latest_action = 'placed' then
    raise exception using errcode = '23514', message = 'settlement evidence already has an active legal hold';
  end if;
  if p_action = 'released' and latest_action is distinct from 'placed' then
    raise exception using errcode = '23514', message = 'settlement evidence has no active legal hold to release';
  end if;

  insert into public.settlement_evidence_retention_holds (
    evidence_id, action, reason, actor_id, request_id
  ) values (
    p_evidence_id, p_action, btrim(p_reason), p_actor_id, p_request_id
  ) returning id into hold_id;

  if p_action = 'placed' then
    update public.settlement_evidence_retention_jobs
    set status = 'blocked',
        claim_token = null,
        claimed_by = null,
        claimed_at = null,
        updated_at = clock_timestamp()
    where evidence_id = p_evidence_id
      and status in ('pending', 'claimed');
  else
    update public.settlement_evidence_retention_jobs
    set status = 'pending',
        updated_at = clock_timestamp()
    where evidence_id = p_evidence_id
      and status = 'blocked';
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_actor_id,
    case when p_action = 'placed'
      then 'settlement.evidence.legal_hold_placed'
      else 'settlement.evidence.legal_hold_released'
    end,
    'settlement_evidence',
    p_evidence_id::text,
    p_request_id::text,
    jsonb_build_object('hold_id', hold_id, 'reason', btrim(p_reason))
  );

  return hold_id;
end;
$function$;

revoke all on function public.set_settlement_evidence_legal_hold(uuid, text, text, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.set_settlement_evidence_legal_hold(uuid, text, text, uuid, uuid)
  to service_role;

create function public.claim_settlement_evidence_retention_jobs(
  p_limit integer,
  p_worker_id text,
  p_request_id uuid
)
returns table (
  job_id uuid,
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  claim_token uuid,
  attempt_count integer,
  scheduled_for timestamptz
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  retention_enabled boolean;
begin
  if p_limit is null or p_limit not between 1 and 50
    or p_worker_id is null or char_length(btrim(p_worker_id)) not between 1 and 120
    or p_request_id is null
  then
    raise exception using errcode = '23514', message = 'settlement evidence retention claim metadata failed validation';
  end if;

  select settings.enabled into retention_enabled
  from public.settlement_evidence_retention_settings settings
  where settings.singleton = true;

  if retention_enabled is distinct from true then
    return;
  end if;

  insert into public.settlement_evidence_retention_jobs (
    evidence_id, storage_path, source_sha256, scheduled_for, request_id
  )
  select
    evidence.id, evidence.storage_path, evidence.source_sha256,
    evidence.retention_until, p_request_id
  from public.settlement_evidence evidence
  where evidence.retention_until <= clock_timestamp()
    and coalesce((
      select hold.action
      from public.settlement_evidence_retention_holds hold
      where hold.evidence_id = evidence.id
      order by hold.created_at desc, hold.id desc
      limit 1
    ), 'released') <> 'placed'
    and not exists (
      select 1
      from public.settlement_evidence_links link
      left join public.settlement_reconciliation_runs run
        on run.import_id = link.import_id
      where link.evidence_id = evidence.id
        and (run.id is null or run.exception_rows > 0)
    )
  on conflict (evidence_id) do nothing;

  update public.settlement_evidence_retention_jobs job
  set status = 'pending',
      updated_at = clock_timestamp()
  where job.status = 'blocked'
    and not exists (
      select 1
      from public.settlement_evidence_retention_holds hold
      where hold.evidence_id = job.evidence_id
        and hold.action = 'placed'
        and hold.id = (
          select latest.id
          from public.settlement_evidence_retention_holds latest
          where latest.evidence_id = job.evidence_id
          order by latest.created_at desc, latest.id desc
          limit 1
        )
    );

  return query
  with candidates as (
    select job.id
    from public.settlement_evidence_retention_jobs job
    join public.settlement_evidence evidence on evidence.id = job.evidence_id
    where (
      job.status = 'pending'
      or (
        job.status = 'claimed'
        and job.claimed_at < clock_timestamp() - interval '15 minutes'
      )
    )
      and job.attempt_count < 5
      and evidence.retention_until <= clock_timestamp()
      and coalesce((
        select hold.action
        from public.settlement_evidence_retention_holds hold
        where hold.evidence_id = evidence.id
        order by hold.created_at desc, hold.id desc
        limit 1
      ), 'released') <> 'placed'
      and not exists (
        select 1
        from public.settlement_evidence_links link
        left join public.settlement_reconciliation_runs run
          on run.import_id = link.import_id
        where link.evidence_id = evidence.id
          and (run.id is null or run.exception_rows > 0)
      )
    order by job.scheduled_for, job.id
    limit p_limit
    for update of job skip locked
  ),
  claimed as (
    update public.settlement_evidence_retention_jobs job
    set status = 'claimed',
        attempt_count = job.attempt_count + 1,
        claim_token = gen_random_uuid(),
        claimed_by = btrim(p_worker_id),
        claimed_at = clock_timestamp(),
        request_id = p_request_id,
        updated_at = clock_timestamp(),
        last_error_code = null
    from candidates
    where job.id = candidates.id
    returning job.id, job.evidence_id, job.storage_path, job.source_sha256,
      job.claim_token, job.attempt_count, job.scheduled_for
  )
  select claimed.id, claimed.evidence_id, claimed.storage_path, claimed.source_sha256,
    claimed.claim_token, claimed.attempt_count, claimed.scheduled_for
  from claimed;
end;
$function$;

revoke all on function public.claim_settlement_evidence_retention_jobs(integer, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.claim_settlement_evidence_retention_jobs(integer, text, uuid)
  to service_role;

create function public.authorize_settlement_evidence_retention_deletion(
  p_job_id uuid,
  p_claim_token uuid,
  p_request_id uuid
)
returns table (
  job_id uuid,
  evidence_id uuid,
  storage_path text,
  source_sha256 text,
  claim_token uuid
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  job_row public.settlement_evidence_retention_jobs%rowtype;
  retention_enabled boolean;
  has_active_hold boolean;
  has_unresolved_exception boolean;
begin
  if p_job_id is null or p_claim_token is null or p_request_id is null then
    raise exception using errcode = '23514', message = 'settlement evidence deletion authorization metadata failed validation';
  end if;

  select * into job_row
  from public.settlement_evidence_retention_jobs job
  where job.id = p_job_id
    and job.status = 'claimed'
    and job.claim_token = p_claim_token
  for update;

  if job_row.id is null then
    return;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('settlement-evidence-retention:' || job_row.evidence_id::text)
  );

  select settings.enabled into retention_enabled
  from public.settlement_evidence_retention_settings settings
  where settings.singleton = true;

  select coalesce((
    select hold.action
    from public.settlement_evidence_retention_holds hold
    where hold.evidence_id = job_row.evidence_id
    order by hold.created_at desc, hold.id desc
    limit 1
  ), 'released') = 'placed'
  into has_active_hold;

  select exists (
    select 1
    from public.settlement_evidence_links link
    left join public.settlement_reconciliation_runs run
      on run.import_id = link.import_id
    where link.evidence_id = job_row.evidence_id
      and (run.id is null or run.exception_rows > 0)
  ) into has_unresolved_exception;

  if retention_enabled is distinct from true or has_active_hold or has_unresolved_exception
    or not exists (
      select 1 from public.settlement_evidence evidence
      where evidence.id = job_row.evidence_id
        and evidence.retention_until <= clock_timestamp()
        and evidence.storage_path = job_row.storage_path
        and evidence.source_sha256 = job_row.source_sha256
    )
  then
    update public.settlement_evidence_retention_jobs
    set status = case when has_active_hold or has_unresolved_exception then 'blocked' else 'pending' end,
        claim_token = null,
        claimed_by = null,
        claimed_at = null,
        updated_at = clock_timestamp()
    where id = job_row.id;

    return;
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    null,
    'settlement.evidence.retention_deletion_authorized',
    'settlement_evidence',
    job_row.evidence_id::text,
    p_request_id::text,
    jsonb_build_object('job_id', job_row.id, 'source_sha256', job_row.source_sha256)
  );

  return query
  select job_row.id, job_row.evidence_id, job_row.storage_path,
    job_row.source_sha256, job_row.claim_token;
end;
$function$;

revoke all on function public.authorize_settlement_evidence_retention_deletion(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.authorize_settlement_evidence_retention_deletion(uuid, uuid, uuid)
  to service_role;

create function public.complete_settlement_evidence_retention_job(
  p_job_id uuid,
  p_claim_token uuid,
  p_success boolean,
  p_error_code text,
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  job_row public.settlement_evidence_retention_jobs%rowtype;
begin
  if p_job_id is null or p_claim_token is null or p_success is null or p_request_id is null
    or (p_success and p_error_code is not null)
    or (not p_success and (p_error_code is null or p_error_code not in (
      'storage_list_failed', 'storage_delete_failed', 'storage_delete_timeout', 'unknown'
    )))
  then
    raise exception using errcode = '23514', message = 'settlement evidence retention completion metadata failed validation';
  end if;

  select * into job_row
  from public.settlement_evidence_retention_jobs job
  where job.id = p_job_id
    and job.status = 'claimed'
    and job.claim_token = p_claim_token
  for update;

  if job_row.id is null then
    raise exception using errcode = '42501', message = 'settlement evidence retention claim is no longer valid';
  end if;

  if p_success then
    update public.settlement_evidence_retention_jobs
    set status = 'deleted',
        claim_token = null,
        claimed_by = null,
        claimed_at = null,
        completed_at = clock_timestamp(),
        last_error_code = null,
        updated_at = clock_timestamp()
    where id = job_row.id;
  else
    update public.settlement_evidence_retention_jobs
    set status = case when attempt_count >= 5 then 'failed' else 'pending' end,
        claim_token = null,
        claimed_by = null,
        claimed_at = null,
        last_error_code = p_error_code,
        updated_at = clock_timestamp()
    where id = job_row.id;
  end if;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    null,
    case when p_success
      then 'settlement.evidence.retention_deleted'
      else 'settlement.evidence.retention_delete_failed'
    end,
    'settlement_evidence',
    job_row.evidence_id::text,
    p_request_id::text,
    jsonb_build_object(
      'job_id', job_row.id,
      'source_sha256', job_row.source_sha256,
      'attempt_count', job_row.attempt_count,
      'error_code', p_error_code
    )
  );
end;
$function$;

revoke all on function public.complete_settlement_evidence_retention_job(uuid, uuid, boolean, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.complete_settlement_evidence_retention_job(uuid, uuid, boolean, text, uuid)
  to service_role;

comment on table public.settlement_evidence_retention_settings is
  'Deletion remains disabled until an admin records a reviewed legal/business basis. Existing per-object retention_until values are policy targets and require legal review before activation.';
comment on table public.settlement_evidence_retention_holds is
  'Append-only legal-hold history. The latest event controls whether evidence is eligible for automated deletion.';
comment on table public.settlement_evidence_retention_jobs is
  'Service-only idempotent deletion queue. Evidence metadata and digest remain immutable after the private storage object is deleted.';
comment on function public.claim_settlement_evidence_retention_jobs(integer, text, uuid) is
  'Claims due evidence objects only while retention is explicitly enabled, no legal hold is active, and linked imports have a reconciliation run with no unresolved exceptions.';
