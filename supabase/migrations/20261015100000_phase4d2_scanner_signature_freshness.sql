-- Phase 4D2: require a fresh ClamAV signature database attestation, not just a recent scan event.
alter table public.settlement_evidence_scan_results
  add column signature_updated_at timestamptz;

drop function public.record_settlement_evidence_scan_result(uuid, text, text, text, text, uuid);

create function public.record_settlement_evidence_scan_result(
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
  evidence_row public.settlement_evidence%rowtype;
  scan_id uuid;
begin
  if p_evidence_id is null or p_request_id is null
    or p_source_sha256 is null or p_source_sha256 !~ '^[a-f0-9]{64}$'
    or p_verdict is null or p_verdict not in ('clean', 'infected', 'error')
    or p_scanner_name is null or char_length(btrim(p_scanner_name)) not between 1 and 120
    or p_scanner_version is null or char_length(btrim(p_scanner_version)) not between 1 and 80
    or p_signature_updated_at is null
    or p_signature_updated_at > clock_timestamp() + interval '5 minutes'
  then
    raise exception using errcode = '23514', message = 'settlement evidence scan result metadata failed validation';
  end if;

  perform pg_advisory_xact_lock(hashtext('settlement-evidence-scan:' || p_evidence_id::text));

  select * into evidence_row
  from public.settlement_evidence
  where id = p_evidence_id
  for share;

  if evidence_row.id is null then
    raise exception using errcode = 'P0002', message = 'settlement evidence was not found';
  end if;

  if evidence_row.source_sha256 <> p_source_sha256 then
    raise exception using errcode = '23514', message = 'settlement evidence scan digest does not match stored evidence';
  end if;

  insert into public.settlement_evidence_scan_results (
    evidence_id, source_sha256, verdict, scanner_name, scanner_version, signature_updated_at, request_id
  ) values (
    p_evidence_id, p_source_sha256, p_verdict, btrim(p_scanner_name), btrim(p_scanner_version), p_signature_updated_at, p_request_id
  ) returning id into scan_id;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    null,
    'settlement.evidence.scan_result_recorded',
    'settlement_evidence',
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
      select scan.verdict, scan.source_sha256, scan.signature_updated_at
      from public.settlement_evidence_scan_results scan
      where scan.evidence_id = p_evidence_id
      order by scan.scanned_at desc, scan.id desc
      limit 1
    ) latest_scan
    where latest_scan.verdict = 'clean'
      and latest_scan.source_sha256 = evidence_row.source_sha256
      and latest_scan.signature_updated_at >= clock_timestamp() - interval '48 hours'
      and latest_scan.signature_updated_at <= clock_timestamp() + interval '5 minutes'
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

revoke all on function public.record_settlement_evidence_scan_result(uuid, text, text, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.record_settlement_evidence_scan_result(uuid, text, text, text, text, timestamptz, uuid)
  to service_role;

comment on column public.settlement_evidence_scan_results.signature_updated_at is
  'Timestamp reported by the scanner for its signature database. Evidence linkage requires a non-null timestamp no older than 48 hours and no more than five minutes in the future.';
