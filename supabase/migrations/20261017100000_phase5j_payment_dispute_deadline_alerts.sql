-- Phase 5J: durable, idempotent operational alerts for approaching/overdue payment-dispute deadlines.
-- This creates alerts only; it does not submit evidence or move funds.
create table public.payment_dispute_alert_jobs (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  alert_kind text not null check (alert_kind in ('due_soon', 'overdue')),
  evidence_due_at timestamptz not null,
  status text not null default 'queued' check (status in ('queued', 'processing', 'retryable', 'sent', 'blocked')),
  attempts integer not null default 0 check (attempts between 0 and 5),
  available_at timestamptz not null default now(),
  lease_expires_at timestamptz,
  last_error_code text check (last_error_code is null or last_error_code ~ '^[a-z0-9_]{1,80}$'),
  last_request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (dispute_id, alert_kind, evidence_due_at),
  constraint payment_dispute_alert_lease_consistency check (
    (status = 'processing' and lease_expires_at is not null and sent_at is null)
    or (status <> 'processing' and lease_expires_at is null)
  ),
  constraint payment_dispute_alert_sent_consistency check (
    (status = 'sent' and sent_at is not null)
    or (status <> 'sent' and sent_at is null)
  ),
  constraint payment_dispute_alert_blocked_attempts check (status <> 'blocked' or attempts = 5)
);

create index payment_dispute_alert_claim_idx
  on public.payment_dispute_alert_jobs (status, available_at, evidence_due_at)
  where status in ('queued', 'retryable', 'processing');

alter table public.payment_dispute_alert_jobs enable row level security;
revoke all on public.payment_dispute_alert_jobs from public, anon, authenticated, service_role;
grant select on public.payment_dispute_alert_jobs to service_role;

create function public.enqueue_payment_dispute_deadline_alerts(p_now timestamptz)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  inserted_count integer;
begin
  if p_now is null then
    raise exception using errcode = '22023', message = 'alert scan time is required';
  end if;

  insert into public.payment_dispute_alert_jobs (
    dispute_id, alert_kind, evidence_due_at, last_request_id
  )
  select d.id,
         case when d.evidence_due_at <= p_now then 'overdue' else 'due_soon' end,
         d.evidence_due_at,
         gen_random_uuid()
  from public.payment_disputes d
  where d.status in ('open', 'needs_evidence')
    and d.evidence_due_at is not null
    and d.evidence_due_at <= p_now + interval '48 hours'
  on conflict (dispute_id, alert_kind, evidence_due_at) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$function$;
revoke all on function public.enqueue_payment_dispute_deadline_alerts(timestamptz) from public, anon, authenticated;
grant execute on function public.enqueue_payment_dispute_deadline_alerts(timestamptz) to service_role;

create function public.claim_payment_dispute_alert_jobs(p_limit integer, p_request_id uuid)
returns table (
  job_id uuid,
  dispute_id uuid,
  provider text,
  provider_dispute_id text,
  dispute_status text,
  alert_kind text,
  evidence_due_at timestamptz,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_limit is null or p_limit < 1 or p_limit > 3 or p_request_id is null then
    raise exception using errcode = '22023', message = 'invalid dispute alert claim request';
  end if;

  update public.payment_dispute_alert_jobs j
  set status = case when j.attempts >= 5 then 'blocked' else 'retryable' end,
      lease_expires_at = null,
      available_at = case
        when j.attempts >= 5 then j.available_at
        else now() + make_interval(secs => least(3600, 60 * power(2, greatest(j.attempts - 1, 0))::integer))
      end,
      updated_at = now()
  where j.status = 'processing' and j.lease_expires_at <= now();

  return query
  with candidates as (
    select j.id
    from public.payment_dispute_alert_jobs j
    join public.payment_disputes d on d.id = j.dispute_id
    where j.status in ('queued', 'retryable')
      and j.available_at <= now()
      and d.status in ('open', 'needs_evidence')
      and d.evidence_due_at = j.evidence_due_at
    order by j.evidence_due_at asc, j.created_at asc
    for update of j skip locked
    limit p_limit
  ), claimed as (
    update public.payment_dispute_alert_jobs j
    set status = 'processing',
        attempts = j.attempts + 1,
        lease_expires_at = now() + interval '10 minutes',
        last_request_id = p_request_id,
        updated_at = now()
    from candidates c
    where j.id = c.id
    returning j.*
  )
  select j.id, d.id, d.provider, d.provider_dispute_id, d.status,
         j.alert_kind, j.evidence_due_at, j.attempts
  from claimed j
  join public.payment_disputes d on d.id = j.dispute_id
  order by j.evidence_due_at asc, j.created_at asc;
end;
$function$;
revoke all on function public.claim_payment_dispute_alert_jobs(integer, uuid) from public, anon, authenticated;
grant execute on function public.claim_payment_dispute_alert_jobs(integer, uuid) to service_role;

create function public.finish_payment_dispute_alert_job(
  p_job_id uuid,
  p_request_id uuid,
  p_success boolean,
  p_error_code text
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  job public.payment_dispute_alert_jobs%rowtype;
  next_status text;
begin
  if p_job_id is null or p_request_id is null or p_success is null
    or (p_error_code is not null and p_error_code !~ '^[a-z0-9_]{1,80}$')
    or (p_success and p_error_code is not null)
    or (not p_success and p_error_code is null)
  then
    raise exception using errcode = '22023', message = 'invalid dispute alert completion';
  end if;

  select * into job
  from public.payment_dispute_alert_jobs j
  where j.id = p_job_id
  for update;

  if not found or job.status <> 'processing' or job.last_request_id <> p_request_id then
    raise exception using errcode = '42501', message = 'dispute alert lease owner mismatch';
  end if;

  if p_success then
    next_status := 'sent';
  elsif job.attempts >= 5 then
    next_status := 'blocked';
  else
    next_status := 'retryable';
  end if;

  update public.payment_dispute_alert_jobs
  set status = next_status,
      lease_expires_at = null,
      sent_at = case when p_success then now() else null end,
      available_at = case
        when next_status = 'retryable'
          then now() + make_interval(secs => least(3600, 60 * power(2, greatest(job.attempts - 1, 0))::integer))
        else available_at
      end,
      last_error_code = p_error_code,
      updated_at = now()
  where id = p_job_id;

  if not p_success then
    insert into public.audit_events (action, entity_type, entity_id, request_id, metadata)
    values (
      'payment.dispute.deadline_alert_failed',
      'payment_dispute_alert_job',
      p_job_id::text,
      p_request_id,
      jsonb_build_object('error_code', p_error_code, 'attempts', job.attempts, 'final_status', next_status)
    );
  end if;

  return next_status;
end;
$function$;
revoke all on function public.finish_payment_dispute_alert_job(uuid, uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.finish_payment_dispute_alert_job(uuid, uuid, boolean, text) to service_role;
