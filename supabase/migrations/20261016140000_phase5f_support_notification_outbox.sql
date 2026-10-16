-- Phase 5F: durable, privacy-minimal support notification outbox.
-- Queue writes are part of the support-case event transaction. Delivery is an
-- external side effect and is performed only by the token-protected worker.
create table public.support_notification_jobs (
  id uuid primary key default gen_random_uuid(),
  case_event_id bigint not null references public.support_case_events(id) on delete restrict,
  case_id uuid not null references public.support_cases(id) on delete restrict,
  event_type text not null check (event_type in ('created', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed', 'reopened', 'assigned')),
  case_status text not null check (case_status in ('open', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed')),
  recipient_kind text not null check (recipient_kind in ('requester', 'operations')),
  recipient_user_id uuid references auth.users(id) on delete restrict,
  status text not null default 'queued' check (status in ('queued', 'processing', 'retryable', 'sent', 'blocked')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  available_at timestamptz not null default now(),
  lease_expires_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[a-z0-9_]{1,80}$'),
  last_request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (case_event_id, recipient_kind),
  constraint support_notification_recipient_consistency check (
    (recipient_kind = 'requester' and recipient_user_id is not null)
    or (recipient_kind = 'operations' and recipient_user_id is null)
  ),
  constraint support_notification_lease_consistency check (
    (status = 'processing' and lease_expires_at is not null and sent_at is null)
    or (status <> 'processing' and lease_expires_at is null)
  ),
  constraint support_notification_sent_consistency check (
    (status = 'sent' and sent_at is not null)
    or (status <> 'sent' and sent_at is null)
  ),
  constraint support_notification_blocked_attempts check (
    status <> 'blocked' or attempts = 5
  )
);

create index support_notification_claim_idx
  on public.support_notification_jobs (status, available_at, created_at)
  where status in ('queued', 'retryable', 'processing');

alter table public.support_notification_jobs enable row level security;
revoke all on public.support_notification_jobs from public, anon, authenticated, service_role;
grant select on public.support_notification_jobs to service_role;

create function public.enqueue_support_case_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requester uuid;
  event_status text;
  event_request_id uuid;
begin
  select c.requester_id into requester
  from public.support_cases c where c.id = new.case_id;
  if requester is null then
    raise exception using errcode = '23503', message = 'support notification case requester missing';
  end if;

  event_status := new.to_status;
  event_request_id := new.request_id;

  insert into public.support_notification_jobs
    (case_event_id, case_id, event_type, case_status, recipient_kind, recipient_user_id, last_request_id)
  values
    (new.id, new.case_id, new.event_type, event_status, 'requester', requester, event_request_id),
    (new.id, new.case_id, new.event_type, event_status, 'operations', null, event_request_id)
  on conflict (case_event_id, recipient_kind) do nothing;

  return new;
end;
$function$;
revoke all on function public.enqueue_support_case_notification() from public, anon, authenticated, service_role;
create trigger support_case_notification_outbox
after insert on public.support_case_events
for each row execute function public.enqueue_support_case_notification();

create function public.claim_support_notification_jobs(
  p_limit integer,
  p_request_id uuid
)
returns table (
  job_id uuid,
  case_id uuid,
  event_type text,
  case_status text,
  recipient_kind text,
  recipient_user_id uuid,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_request_id is null or p_limit is null or p_limit < 1 or p_limit > 10 then
    raise exception using errcode = '22023', message = 'support notification claim limit or request id is invalid';
  end if;

  with exhausted as (
    update public.support_notification_jobs j
    set status = 'blocked',
        lease_expires_at = null,
        last_error_code = 'worker_lease_exhausted',
        updated_at = now(),
        last_request_id = p_request_id
    where j.status = 'processing'
      and j.lease_expires_at <= now()
      and j.attempts >= 5
    returning j.id, j.case_id, j.recipient_kind, j.attempts
  )
  insert into public.audit_events
    (actor_id, action, entity_type, entity_id, request_id, metadata)
  select null, 'support.notification.delivery_failed', 'support_notification_job',
    exhausted.id::text, p_request_id,
    jsonb_build_object('case_id', exhausted.case_id,
      'recipient_kind', exhausted.recipient_kind,
      'attempt', exhausted.attempts, 'status', 'blocked',
      'error_code', 'worker_lease_exhausted')
  from exhausted;

  return query
  with candidates as (
    select j.id
    from public.support_notification_jobs j
    where (
      j.status in ('queued', 'retryable') and j.available_at <= now()
    ) or (
      j.status = 'processing' and j.lease_expires_at <= now() and j.attempts < 5
    )
    order by j.available_at, j.created_at, j.id
    for update skip locked
    limit p_limit
  )
  update public.support_notification_jobs j
  set status = 'processing',
      attempts = j.attempts + 1,
      lease_expires_at = now() + interval '10 minutes',
      last_error_code = null,
      last_request_id = p_request_id,
      updated_at = now()
  from candidates c
  where j.id = c.id
  returning j.id, j.case_id, j.event_type, j.case_status,
    j.recipient_kind, j.recipient_user_id, j.attempts;
end;
$function$;
revoke all on function public.claim_support_notification_jobs(integer, uuid) from public, anon, authenticated;
grant execute on function public.claim_support_notification_jobs(integer, uuid) to service_role;

create function public.finish_support_notification_job(
  p_job_id uuid,
  p_request_id uuid,
  p_sent boolean,
  p_error_code text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  job public.support_notification_jobs%rowtype;
  next_status text;
begin
  if p_job_id is null or p_request_id is null or p_sent is null
    or (p_error_code is not null and p_error_code !~ '^[a-z0-9_]{1,80}$')
    or (p_sent and p_error_code is not null)
    or (not p_sent and p_error_code is null)
  then
    raise exception using errcode = '22023', message = 'support notification completion metadata is invalid';
  end if;

  select * into job from public.support_notification_jobs
  where id = p_job_id for update;
  if not found or job.status <> 'processing' or job.last_request_id <> p_request_id then
    raise exception using errcode = '55000', message = 'support notification lease is not owned by this worker';
  end if;

  if p_sent then
    next_status := 'sent';
    update public.support_notification_jobs
    set status = next_status, lease_expires_at = null, sent_at = now(),
        last_error_code = null, updated_at = now()
    where id = p_job_id;
  else
    next_status := case when job.attempts >= 5 then 'blocked' else 'retryable' end;
    update public.support_notification_jobs
    set status = next_status, lease_expires_at = null, sent_at = null,
        last_error_code = p_error_code,
        available_at = case when next_status = 'retryable'
          then now() + make_interval(secs => least(3600, 30 * (2 ^ greatest(job.attempts - 1, 0))::integer))
          else available_at end,
        updated_at = now()
    where id = p_job_id;

    insert into public.audit_events
      (actor_id, action, entity_type, entity_id, request_id, metadata)
    values
      (null, 'support.notification.delivery_failed', 'support_notification_job',
       p_job_id::text, p_request_id,
       jsonb_build_object('case_id', job.case_id, 'recipient_kind', job.recipient_kind,
         'attempt', job.attempts, 'status', next_status, 'error_code', p_error_code));
  end if;

  return next_status;
end;
$function$;
revoke all on function public.finish_support_notification_job(uuid, uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.finish_support_notification_job(uuid, uuid, boolean, text) to service_role;

comment on table public.support_notification_jobs is
  'Private transactional outbox for support-case notifications. Payload excludes case descriptions, notes, payment data, and secrets; retries are bounded and audited.';
