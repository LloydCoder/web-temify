begin;
select plan(51);

select has_table('public', 'listing_moderation_enforcements', 'takedown enforcement records exist');
select has_table('public', 'listing_moderation_appeal_policy', 'appeal response policy exists');
select has_table('public', 'listing_moderation_appeals', 'creator appeals exist');
select has_table('public', 'listing_moderation_appeal_events', 'appeal event history exists');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_enforcements'::regclass), 'enforcement RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_appeal_policy'::regclass), 'appeal policy RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_appeals'::regclass), 'appeal RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.listing_moderation_appeal_events'::regclass), 'appeal event RLS is enabled');
select ok(not has_table_privilege('anon', 'public.listing_moderation_enforcements', 'SELECT'), 'anonymous users cannot read takedown records');
select ok(not has_table_privilege('authenticated', 'public.listing_moderation_appeals', 'SELECT'), 'authenticated clients cannot read internal appeal records');
select ok(has_table_privilege('service_role', 'public.listing_moderation_enforcements', 'SELECT'), 'trusted server can read enforcement records');
select ok(not has_table_privilege('service_role', 'public.listing_moderation_enforcements', 'UPDATE'), 'enforcement changes must use guarded RPCs');
select ok(has_table_privilege('service_role', 'public.listing_moderation_appeals', 'SELECT'), 'trusted server can read appeal records');
select ok(has_function_privilege('service_role', 'public.admin_apply_listing_takedown(uuid,uuid,text,uuid)', 'EXECUTE'), 'trusted server can apply an approved takedown');
select ok(not has_function_privilege('authenticated', 'public.admin_apply_listing_takedown(uuid,uuid,text,uuid)', 'EXECUTE'), 'authenticated clients cannot apply takedowns');
select ok(has_function_privilege('service_role', 'public.create_listing_moderation_appeal(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'trusted server can accept creator appeals');
select ok(not has_function_privilege('authenticated', 'public.create_listing_moderation_appeal(uuid,uuid,text,text,text,uuid)', 'EXECUTE'), 'authenticated clients cannot call the appeal RPC directly');
select ok(has_function_privilege('service_role', 'public.admin_transition_listing_moderation_appeal(uuid,uuid,text,text,uuid)', 'EXECUTE'), 'trusted server can decide appeals');
select ok(has_function_privilege('service_role', 'public.admin_configure_listing_moderation_appeal_policy(uuid,integer,text,text,text,uuid)', 'EXECUTE'), 'trusted server can record approved appeal response policy');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
) values
  ('b1000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase5e2-creator@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('b2000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase5e2-reporter@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('b3000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase5e2-admin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('b4000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase5e2-nonadmin@example.test', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.user_roles (user_id, role)
values ('b3000000-0000-4000-8000-000000000003', 'admin'::public.app_role);

insert into public.products (
  id, creator_id, slug, name, description, product_type, status,
  rights_status, rights_verified_at, rights_verified_by, artifact_sha256
) values
  ('b5000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001',
   'phase5e2-takedown-one', 'Phase 5E2 test listing one', 'Fixture listing for takedown and appeal workflow.',
   'template', 'published', 'verified', '2026-01-01T00:00:00Z', 'b3000000-0000-4000-8000-000000000003',
   repeat('a', 64)),
  ('b6000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001',
   'phase5e2-takedown-two', 'Phase 5E2 test listing two', 'Fixture listing for takedown and appeal workflow.',
   'template', 'published', 'verified', '2026-01-01T00:00:00Z', 'b3000000-0000-4000-8000-000000000003',
   repeat('b', 64));

insert into public.product_rights_attestations
  (product_id, attested_by, rights_basis, statement, review_status, reviewed_by, reviewed_at)
values
  ('b5000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000001',
   'original_work', 'Test fixture independently confirms the creator owns this sample listing.', 'verified',
   'b3000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z'),
  ('b6000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000001',
   'original_work', 'Test fixture independently confirms the creator owns this sample listing.', 'verified',
   'b3000000-0000-4000-8000-000000000003', '2026-01-01T00:00:00Z');

insert into public.product_versions
  (product_id, version, release_state, release_notes, artifact_sha256, artifact_storage_path, created_by, released_at)
values
  ('b5000000-0000-4000-8000-000000000005', '1.0.0', 'released', 'Verified test release.',
   repeat('a', 64), 'private/test/phase5e2-one.zip', 'b1000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z'),
  ('b6000000-0000-4000-8000-000000000006', '1.0.0', 'released', 'Verified test release.',
   repeat('b', 64), 'private/test/phase5e2-two.zip', 'b1000000-0000-4000-8000-000000000001', '2026-01-01T00:00:00Z');

create temporary table phase5e2_ids (
  product_id uuid primary key,
  case_id uuid not null,
  enforcement_id uuid,
  appeal_id uuid
) on commit drop;

insert into phase5e2_ids (product_id, case_id)
values
  ('b5000000-0000-4000-8000-000000000005',
   public.create_listing_moderation_case(
     'b2000000-0000-4000-8000-000000000002', 'b5000000-0000-4000-8000-000000000005',
     'ip_rights', 'The listing appears to reproduce protected source material without permission.',
     'phase5e2-case-key-00001', 'b7000000-0000-4000-8000-000000000007')),
  ('b6000000-0000-4000-8000-000000000006',
   public.create_listing_moderation_case(
     'b2000000-0000-4000-8000-000000000002', 'b6000000-0000-4000-8000-000000000006',
     'ip_rights', 'The listing appears to reproduce protected source material without permission.',
     'phase5e2-case-key-00002', 'b8000000-0000-4000-8000-000000000008'));

select lives_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select case_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'b3000000-0000-4000-8000-000000000003', 'triage', null,
    'Independent review has started for this listing report.',
    'b9000000-0000-4000-8000-000000000009'
  )$sql$,
  'first case can be triaged'
);
select lives_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select case_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'b3000000-0000-4000-8000-000000000003', 'require_action', 'rights_review_required',
    'Independent rights review found sufficient grounds for a temporary takedown.',
    'ba000000-0000-4000-8000-00000000000a'
  )$sql$,
  'first case reaches the approved takedown disposition'
);
select lives_ok(
  $sql$update phase5e2_ids
    set enforcement_id = (public.admin_apply_listing_takedown(
      case_id, 'b3000000-0000-4000-8000-000000000003',
      'Independent rights review requires this published listing to be suppressed.',
      'bb000000-0000-4000-8000-00000000000b'
    )).id
    where product_id = 'b5000000-0000-4000-8000-000000000005'$sql$,
  'admin takedown applies atomically'
);
select is((select status from public.products where id = 'b5000000-0000-4000-8000-000000000005'), 'archived', 'takedown removes the product from published catalogue queries');
select is((select status from public.listing_moderation_enforcements where id = (select enforcement_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005')), 'active', 'enforcement remains active until an appeal is reversed');

select lives_ok(
  $sql$update phase5e2_ids
    set appeal_id = (public.create_listing_moderation_appeal(
      'b1000000-0000-4000-8000-000000000001', enforcement_id,
      'The creator requests independent reconsideration and supplies ownership evidence.',
      'private-evidence://phase5e2-appeal-one', 'phase5e2-appeal-key-00001',
      'bc000000-0000-4000-8000-00000000000c'
    )).id
    where product_id = 'b5000000-0000-4000-8000-000000000005'$sql$,
  'creator can submit an appeal for their own active takedown'
);
select is((select status from public.listing_moderation_appeals where id = (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005')), 'submitted', 'appeal starts submitted');
select is((select response_due_at from public.listing_moderation_appeals where id = (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005')), null::timestamptz, 'no response deadline is invented before the policy is approved');

select is(
  (public.create_listing_moderation_appeal(
    'b1000000-0000-4000-8000-000000000001',
    (select enforcement_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'The creator requests independent reconsideration and supplies ownership evidence.',
    'private-evidence://phase5e2-appeal-one', 'phase5e2-appeal-key-00001',
    'c7000000-0000-4000-8000-000000000017'
  )).id,
  (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
  'idempotent replay returns the original appeal'
);
select throws_ok(
  $sql$select public.create_listing_moderation_appeal(
    'b1000000-0000-4000-8000-000000000001',
    (select enforcement_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'The creator changes the statement after using the same idempotency key.',
    'private-evidence://phase5e2-appeal-one', 'phase5e2-appeal-key-00001',
    'c8000000-0000-4000-8000-000000000018'
  )$sql$,
  '23505',
  'appeal idempotency key reused with conflicting content',
  'idempotency key reuse with conflicting content is rejected'
);
select throws_ok(
  $sql$select public.create_listing_moderation_appeal(
    'b4000000-0000-4000-8000-000000000004',
    (select enforcement_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'An unrelated user attempts to appeal this creator listing.',
    'private-evidence://phase5e2-non-owner', 'phase5e2-nonowner-key-00001',
    'c9000000-0000-4000-8000-000000000019'
  )$sql$,
  '42501',
  'only the product creator can appeal this active takedown',
  'a non-owner cannot appeal another creator listing'
);

select lives_ok(
  $sql$select public.admin_configure_listing_moderation_appeal_policy(
    'b3000000-0000-4000-8000-000000000003', 72, 'internal-sla-v1',
    'Approved internal review target after legal review; not a statutory deadline.',
    'legal-review-ticket-2026-10-16',
    'bd000000-0000-4000-8000-00000000000d'
  )$sql$,
  'admin can configure a response target with an explicit legal-review reference'
);
select ok((select is_approved from public.listing_moderation_appeal_policy where singleton), 'appeal response policy is explicitly approved and audited');

select lives_ok(
  $sql$select public.admin_transition_listing_moderation_appeal(
    (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'b3000000-0000-4000-8000-000000000003', 'triage',
    'An independent moderator has accepted the appeal for review.',
    'be000000-0000-4000-8000-00000000000e'
  )$sql$,
  'appeal can be moved into independent review'
);
select lives_ok(
  $sql$select public.admin_transition_listing_moderation_appeal(
    (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005'),
    'b3000000-0000-4000-8000-000000000003', 'uphold',
    'The appeal did not overcome the evidence supporting the takedown.',
    'bf000000-0000-4000-8000-00000000000f'
  )$sql$,
  'moderator can uphold the takedown after review'
);
select is((select status from public.listing_moderation_appeals where id = (select appeal_id from phase5e2_ids where product_id = 'b5000000-0000-4000-8000-000000000005')), 'upheld', 'first appeal records an upheld outcome');
select is((select status from public.products where id = 'b5000000-0000-4000-8000-000000000005'), 'archived', 'upheld appeal does not restore public visibility');

select lives_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select case_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006'),
    'b3000000-0000-4000-8000-000000000003', 'triage', null,
    'Independent review has started for the second listing report.',
    'c0000000-0000-4000-8000-000000000010'
  )$sql$,
  'second case can be triaged'
);
select lives_ok(
  $sql$select public.admin_transition_listing_moderation_case(
    (select case_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006'),
    'b3000000-0000-4000-8000-000000000003', 'require_action', 'rights_review_required',
    'Independent rights review requires temporary suppression pending creator appeal.',
    'c1000000-0000-4000-8000-000000000011'
  )$sql$,
  'second case reaches the approved takedown disposition'
);
select lives_ok(
  $sql$update phase5e2_ids
    set enforcement_id = (public.admin_apply_listing_takedown(
      case_id, 'b3000000-0000-4000-8000-000000000003',
      'Independent rights review requires this published listing to be suppressed.',
      'c2000000-0000-4000-8000-000000000012'
    )).id
    where product_id = 'b6000000-0000-4000-8000-000000000006'$sql$,
  'second admin takedown applies atomically'
);
select lives_ok(
  $sql$update phase5e2_ids
    set appeal_id = (public.create_listing_moderation_appeal(
      'b1000000-0000-4000-8000-000000000001', enforcement_id,
      'The creator requests independent reconsideration and supplies ownership evidence.',
      'private-evidence://phase5e2-appeal-two', 'phase5e2-appeal-key-00002',
      'c3000000-0000-4000-8000-000000000013'
    )).id
    where product_id = 'b6000000-0000-4000-8000-000000000006'$sql$,
  'second creator appeal is accepted'
);
select ok((select response_due_at > now() from public.listing_moderation_appeals where id = (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006')), 'approved internal response target creates an auditable deadline');

select lives_ok(
  $sql$select public.admin_transition_listing_moderation_appeal(
    (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006'),
    'b3000000-0000-4000-8000-000000000003', 'triage',
    'An independent moderator has accepted the appeal for review.',
    'c4000000-0000-4000-8000-000000000014'
  )$sql$,
  'second appeal can enter independent review'
);
select lives_ok(
  $sql$select public.admin_transition_listing_moderation_appeal(
    (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006'),
    'b3000000-0000-4000-8000-000000000003', 'reverse',
    'Independent evidence resolves the appeal in the creator’s favour.',
    'c5000000-0000-4000-8000-000000000015'
  )$sql$,
  'moderator can reverse a takedown after appeal review'
);
select is((select status from public.listing_moderation_appeals where id = (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006')), 'reversed', 'appeal records a reversed outcome');
select is((select status from public.products where id = 'b6000000-0000-4000-8000-000000000006'), 'published', 'reversal restores publication only after independent rights and release checks pass');
select is((select status from public.listing_moderation_enforcements where id = (select enforcement_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006')), 'reversed', 'enforcement records its reversal');
select ok((select publication_restored from public.listing_moderation_enforcements where id = (select enforcement_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006')), 'enforcement records whether publication was restored');
select is((select count(*)::integer from public.listing_moderation_appeal_events where appeal_id in (select appeal_id from phase5e2_ids)), 6, 'appeal event history records submission and review outcomes');
select is((select count(*)::integer from public.audit_events where entity_type = 'listing_moderation_appeal'), 6, 'appeal submission, policy configuration and decisions leave audit evidence');
select throws_ok(
  $sql$select public.admin_transition_listing_moderation_appeal(
    (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006'),
    'b4000000-0000-4000-8000-000000000004', 'triage',
    'A non-admin must not be able to transition a moderation appeal.',
    'c6000000-0000-4000-8000-000000000016'
  )$sql$,
  '42501',
  'administrator role required',
  'non-admin appeal transition is denied'
);
select throws_ok(
  $sql$delete from public.listing_moderation_appeal_events where appeal_id = (select appeal_id from phase5e2_ids where product_id = 'b6000000-0000-4000-8000-000000000006')$sql$,
  '55000',
  'moderation appeal events are append-only',
  'appeal event history cannot be deleted'
);

select * from finish();
rollback;
