-- Phase 5D: auditable support-case lifecycle with server-owned writes.
create table public.support_cases (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete restrict,
  category text not null check (category in ('account', 'billing', 'product_access', 'product_rights', 'security', 'other')),
  subject text not null check (char_length(btrim(subject)) between 5 and 160),
  description text not null check (char_length(btrim(description)) between 10 and 8000),
  status text not null default 'open' check (status in ('open', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed')),
  priority text not null default 'normal' check (priority in ('normal', 'high', 'critical')),
  assigned_to uuid references auth.users(id) on delete restrict,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  closed_at timestamptz,
  constraint support_case_requester_idempotency_unique unique (requester_id, idempotency_key),
  constraint support_case_resolution_timestamp check (
    (status in ('resolved', 'closed') and resolved_at is not null)
    or (status not in ('resolved', 'closed') and resolved_at is null)
  ),
  constraint support_case_closure_timestamp check (
    (status = 'closed' and closed_at is not null)
    or (status <> 'closed' and closed_at is null)
  )
);

create table public.support_case_events (
  id bigint generated always as identity primary key,
  case_id uuid not null references public.support_cases(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null check (event_type in ('created', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed', 'reopened', 'assigned')),
  from_status text check (from_status is null or from_status in ('open', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed')),
  to_status text not null check (to_status in ('open', 'triaged', 'waiting_on_requester', 'escalated', 'resolved', 'closed')),
  note text check (note is null or char_length(note) <= 2000),
  request_id uuid not null,
  created_at timestamptz not null default now()
);

create index support_cases_queue_idx on public.support_cases (status, priority, updated_at desc);
create index support_cases_requester_idx on public.support_cases (requester_id, created_at desc);
create index support_case_events_case_idx on public.support_case_events (case_id, created_at, id);

alter table public.support_cases enable row level security;
alter table public.support_case_events enable row level security;
revoke all on public.support_cases from public, anon, authenticated, service_role;
revoke all on public.support_case_events from public, anon, authenticated, service_role;
grant select on public.support_cases to service_role;
grant select on public.support_case_events to service_role;

create function public.reject_support_case_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'support case events are append-only';
end;
$function$;
revoke all on function public.reject_support_case_event_mutation() from public, anon, authenticated, service_role;
create trigger support_case_events_immutable
before update or delete on public.support_case_events
for each row execute function public.reject_support_case_event_mutation();

create function public.create_support_case(
  p_requester_id uuid,
  p_category text,
  p_subject text,
  p_description text,
  p_idempotency_key text,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  existing_case public.support_cases%rowtype;
  new_case_id uuid;
begin
  if p_requester_id is null or p_request_id is null
    or p_category is null or p_category not in ('account', 'billing', 'product_access', 'product_rights', 'security', 'other')
    or p_subject is null or char_length(btrim(p_subject)) not between 5 and 160
    or p_description is null or char_length(btrim(p_description)) not between 10 and 8000
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 16 and 200
  then
    raise exception using errcode = '22023', message = 'support case request failed validation';
  end if;

  if not exists (select 1 from auth.users u where u.id = p_requester_id) then
    raise exception using errcode = '42501', message = 'support case requester does not exist';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_requester_id::text || ':' || p_idempotency_key, 0));

  select * into existing_case
  from public.support_cases
  where requester_id = p_requester_id and idempotency_key = p_idempotency_key
  for update;

  if found then
    if existing_case.category is distinct from p_category
      or existing_case.subject is distinct from btrim(p_subject)
      or existing_case.description is distinct from btrim(p_description)
    then
      raise exception using errcode = '23505', message = 'support case idempotency key reused with conflicting content';
    end if;
    return existing_case.id;
  end if;

  insert into public.support_cases (
    requester_id, category, subject, description, idempotency_key, request_id
  ) values (
    p_requester_id, p_category, btrim(p_subject), btrim(p_description), p_idempotency_key, p_request_id
  ) returning id into new_case_id;

  insert into public.support_case_events (
    case_id, actor_id, event_type, from_status, to_status, note, request_id
  ) values (
    new_case_id, p_requester_id, 'created', null, 'open', 'Support case created', p_request_id
  );

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_requester_id, 'support.case.created', 'support_case', new_case_id::text, p_request_id,
    jsonb_build_object('category', p_category, 'status', 'open')
  );

  return new_case_id;
end;
$function$;
revoke all on function public.create_support_case(uuid, text, text, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_support_case(uuid, text, text, text, text, uuid) to service_role;

create function public.admin_transition_support_case(
  p_case_id uuid,
  p_actor_id uuid,
  p_action text,
  p_note text,
  p_assignee_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  current_case public.support_cases%rowtype;
  next_status text;
  next_assignee uuid;
  event_type_value text;
  result_value jsonb;
begin
  if p_case_id is null or p_actor_id is null or p_request_id is null
    or p_action not in ('triage', 'request_info', 'escalate', 'resolve', 'close', 'reopen', 'assign')
    or p_note is null or char_length(btrim(p_note)) not between 10 and 2000
  then
    raise exception using errcode = '22023', message = 'support case action failed validation';
  end if;
  if not exists (
    select 1 from public.user_roles ur
    where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'support case action requires an admin';
  end if;

  select * into current_case
  from public.support_cases
  where id = p_case_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'support case not found';
  end if;

  next_status := current_case.status;
  next_assignee := current_case.assigned_to;
  event_type_value := p_action;

  case p_action
    when 'triage' then
      if current_case.status not in ('open', 'escalated') then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'triaged';
      event_type_value := 'triaged';
    when 'request_info' then
      if current_case.status not in ('triaged', 'escalated') then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'waiting_on_requester';
      event_type_value := 'waiting_on_requester';
    when 'escalate' then
      if current_case.status not in ('open', 'triaged', 'waiting_on_requester') then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'escalated';
      event_type_value := 'escalated';
    when 'resolve' then
      if current_case.status not in ('triaged', 'waiting_on_requester', 'escalated') then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'resolved';
      event_type_value := 'resolved';
    when 'close' then
      if current_case.status <> 'resolved' then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'closed';
      event_type_value := 'closed';
    when 'reopen' then
      if current_case.status not in ('resolved', 'closed') then
        raise exception using errcode = '22023', message = 'invalid support case transition';
      end if;
      next_status := 'open';
      event_type_value := 'reopened';
    when 'assign' then
      if current_case.status = 'closed' or p_assignee_id is null or not exists (
        select 1 from public.user_roles ur
        where ur.user_id = p_assignee_id and ur.role = 'admin'::public.app_role
      ) then
        raise exception using errcode = '22023', message = 'support case assignee must be an active admin and case must not be closed';
      end if;
      next_assignee := p_assignee_id;
      event_type_value := 'assigned';
    else
      raise exception using errcode = '22023', message = 'unsupported support case action';
  end case;

  update public.support_cases
  set status = next_status,
      assigned_to = next_assignee,
      updated_at = now(),
      resolved_at = case when next_status in ('resolved', 'closed') then coalesce(resolved_at, now()) when p_action = 'reopen' then null else resolved_at end,
      closed_at = case when next_status = 'closed' then now() when p_action = 'reopen' then null else closed_at end
  where id = p_case_id;

  insert into public.support_case_events (
    case_id, actor_id, event_type, from_status, to_status, note, request_id
  ) values (
    p_case_id, p_actor_id, event_type_value, current_case.status, next_status, btrim(p_note), p_request_id
  );

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_actor_id, 'support.case.' || p_action, 'support_case', p_case_id::text, p_request_id,
    jsonb_build_object('from_status', current_case.status, 'to_status', next_status, 'assigned_to', next_assignee)
  );

  select jsonb_build_object('id', id, 'status', status, 'assignedTo', assigned_to, 'updatedAt', updated_at)
    into result_value from public.support_cases where id = p_case_id;
  return result_value;
end;
$function$;
revoke all on function public.admin_transition_support_case(uuid, uuid, text, text, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_transition_support_case(uuid, uuid, text, text, uuid, uuid) to service_role;

comment on table public.support_cases is
  'Server-managed support workflow. Customer content is accessible only through authenticated, ownership-scoped server routes; all state transitions require the audited admin RPC.';
comment on table public.support_case_events is
  'Append-only support-case state history. Event updates and deletion are rejected.';
