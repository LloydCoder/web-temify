import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire(
  new URL("./phase4d2-concurrency/package.json", import.meta.url),
);
const { Pool } = require("pg");

const connectionString =
  process.env.SUPABASE_DB_URL ?? process.env.DB_URL ?? process.env.DATABASE_URL;
assert.ok(
  connectionString,
  "Set SUPABASE_DB_URL (for local Supabase, use the DB_URL from `supabase status -o env`).",
);

const pool = new Pool({
  connectionString,
  max: 6,
  connectionTimeoutMillis: 10_000,
  idleTimeoutMillis: 5_000,
  statement_timeout: 20_000,
  application_name: "web-temify-phase4d2-concurrency-test",
});
const digest = (value) => createHash("sha256").update(value).digest("hex");
const date = new Date().toISOString().slice(0, 10);
const occurredAt = `${date}T10:00:00.000Z`;
const rounds = Number.parseInt(process.env.PHASE4D2_RACE_ROUNDS ?? "4", 10);
assert.ok(
  Number.isInteger(rounds) && rounds >= 2 && rounds <= 20,
  "PHASE4D2_RACE_ROUNDS must be between 2 and 20.",
);

function makeBarrier(parties, timeoutMs = 10_000) {
  let arrivals = 0;
  let release;
  let fail;
  const gate = new Promise((resolve, reject) => {
    release = resolve;
    fail = reject;
  });
  const timeout = setTimeout(() => {
    fail(
      new Error(
        `Concurrent worker barrier timed out after ${timeoutMs}ms (${arrivals}/${parties} workers arrived).`,
      ),
    );
  }, timeoutMs);
  timeout.unref();
  return async () => {
    arrivals += 1;
    if (arrivals === parties) {
      clearTimeout(timeout);
      release();
    }
    await gate;
  };
}

async function insertUser(client, id, email) {
  await client.query(
    `insert into auth.users (
       id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
       created_at, updated_at, raw_app_meta_data, raw_user_meta_data
     ) values (
       $1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       $2, '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb
     )`,
    [id, email],
  );
}

async function prepareRace(setup, iteration) {
  const tag = `phase4d2-race-${process.pid}-${randomUUID()}`;
  const sellerId = randomUUID();
  const customerId = randomUUID();
  const importerId = randomUUID();
  const reviewerId = randomUUID();
  const categoryId = randomUUID();
  const productId = randomUUID();
  const versionId = randomUUID();
  const orderId = randomUUID();
  const itemId = randomUUID();
  const attemptId = randomUUID();
  const providerReference = `${tag}-provider-payment`;

  await setup.query("begin");
  try {
    await insertUser(setup, sellerId, `${tag}-seller@example.test`);
    await insertUser(setup, customerId, `${tag}-customer@example.test`);
    await insertUser(setup, importerId, `${tag}-importer@example.test`);
    await insertUser(setup, reviewerId, `${tag}-reviewer@example.test`);
    await setup.query(
      `insert into public.user_roles (user_id, role)
       values ($1, 'admin'::public.app_role), ($2, 'admin'::public.app_role)
       on conflict do nothing`,
      [importerId, reviewerId],
    );
    await setup.query(
      `insert into public.categories (id, slug, name, is_active)
       values ($1, $2, $3, true)`,
      [categoryId, `${tag}-category`, `Concurrency test ${iteration}`],
    );
    await setup.query(
      `insert into public.products (
         id, creator_id, category_id, slug, name, description, product_type, status,
         price_minor, currency, rights_status, rights_verified_at, rights_verified_by,
         artifact_sha256, release_version, license_type, summary
       ) values (
         $1, $2, $3, $4, $5, $6, 'template', 'published', 1299, 'USD', 'verified',
         now(), $7, $8, '1.0.0', 'standard', $9
       )`,
      [
        productId,
        sellerId,
        categoryId,
        `${tag}-product`,
        `Concurrency test product ${iteration}`,
        "Synthetic sandbox-only fixture for settlement reconciliation concurrency tests.",
        importerId,
        digest(`${tag}-artifact`),
        "Synthetic verified settlement fixture",
      ],
    );
    await setup.query(
      `insert into public.product_rights_attestations (
         product_id, attested_by, rights_basis, statement, evidence_reference,
         review_status, reviewed_by, reviewed_at
       ) values ($1, $2, 'original_work', $3, $4, 'verified', $5, now())`,
      [
        productId,
        sellerId,
        "Synthetic test artifact created for isolated database concurrency tests.",
        `test-fixture://phase4d2/${tag}/rights`,
        importerId,
      ],
    );
    await setup.query(
      `insert into public.product_versions (
         id, product_id, version, release_state, release_notes, artifact_sha256,
         artifact_storage_path, manifest, compatibility, created_by, released_at
       ) values ($1, $2, '1.0.0', 'released', $3, $4, $5, '{}'::jsonb, '{}'::jsonb, $6, now())`,
      [
        versionId,
        productId,
        "Synthetic settlement test artifact.",
        digest(`${tag}-artifact`),
        `private/phase4d2/${tag}/product-1.0.0.zip`,
        sellerId,
      ],
    );

    await setup.query(
      "set constraints orders_totals_guard, order_items_totals_guard deferred",
    );
    await setup.query(
      `insert into public.orders (id, customer_id, currency, subtotal_minor, tax_minor, idempotency_key)
       values ($1, $2, 'USD', 1299, 0, $3)`,
      [orderId, customerId, `${tag}-order-idempotency`],
    );
    await setup.query(
      `insert into public.order_items (
         id, order_id, product_id, product_version_id, seller_id, product_name, product_slug,
         release_version, license_type, artifact_sha256, unit_amount_minor, quantity, currency
       ) values ($1, $2, $3, $4, $5, $6, $7, '1.0.0', 'standard', $8, 1299, 1, 'USD')`,
      [
        itemId,
        orderId,
        productId,
        versionId,
        sellerId,
        `Concurrency test product ${iteration}`,
        `${tag}-product`,
        digest(`${tag}-artifact`),
      ],
    );
    await setup.query(
      "set constraints orders_totals_guard, order_items_totals_guard immediate",
    );
    await setup.query(
      `insert into public.payment_attempts (id, order_id, provider, amount_minor, currency, idempotency_key)
       values ($1, $2, 'sandbox', 1299, 'USD', $3)`,
      [attemptId, orderId, `${tag}-payment-attempt-idempotency`],
    );
    await setup.query(
      "update public.payment_attempts set status = 'pending' where id = $1",
      [attemptId],
    );
    const event = await setup.query(
      `insert into public.payment_webhook_events (
         provider, provider_event_id, event_type, payload_sha256, signature_verified,
         order_id, payment_attempt_id, amount_minor, currency, provider_reference
       ) values ('sandbox', $1, 'payment.succeeded', $2, true, $3, $4, 1299, 'USD', $5)
       returning id`,
      [
        `${tag}-verified-payment-event`,
        digest(`${tag}-webhook-payload`),
        orderId,
        attemptId,
        providerReference,
      ],
    );
    const processed = await setup.query(
      "select public.process_payment_webhook_event($1) as processed",
      [event.rows[0].id],
    );
    assert.equal(
      processed.rows[0].processed,
      true,
      "the verified sandbox webhook must create the legitimate posted journal",
    );

    const journal = await setup.query(
      `select id from public.financial_journal_batches
       where provider = 'sandbox' and provider_reference = $1 and source_type = 'payment' and status = 'posted'`,
      [providerReference],
    );
    assert.equal(
      journal.rowCount,
      1,
      "the sandbox webhook must create exactly one posted payment journal",
    );
    const journalBatchId = journal.rows[0].id;

    const importIds = [];
    for (const side of ["a", "b"]) {
      const importResult = await setup.query(
        `select public.import_settlement_report(
           'sandbox', $1, $2, $3::date, $3::date, 'UTC', $4, true,
           'sandbox_fixture', 'USD', $5::uuid,
           jsonb_build_array(jsonb_build_object(
             'rowId', $6::text, 'rowType', 'payment', 'providerReference', $7::text,
             'paymentReference', $8::text, 'occurredAt', $9::text, 'currency', 'USD',
             'grossMinor', 1299, 'feeMinor', 39, 'netMinor', 1260
           ))
         ) as import_id`,
        [
          `${tag}-account`,
          `${tag}-settlement-report-${side}`,
          date,
          digest(`${tag}-source-${side}`),
          importerId,
          `${tag}-row-${side}`,
          providerReference,
          `${tag}-payment-reference-${side}`,
          occurredAt,
        ],
      );
      importIds.push(importResult.rows[0].import_id);
    }

    await setup.query("commit");
    return {
      tag,
      importerId,
      reviewerId,
      providerReference,
      journalBatchId,
      importIds,
    };
  } catch (error) {
    await setup.query("rollback").catch(() => {});
    throw error;
  }
}

async function reconcileWorker(client, importId, reviewerId, barrier) {
  let inTransaction = false;
  try {
    await client.query("begin");
    inTransaction = true;
    await client.query("set local statement_timeout = '15s'");
    await client.query("set local lock_timeout = '10s'");
    await barrier();
    // Both independent sessions wait at the same point before invoking the RPC,
    // ensuring the race is not a sequential pair of function calls.
    await client.query("select pg_sleep(0.1)");
    const result = await client.query(
      "select public.reconcile_settlement_import($1::uuid, $2::uuid) as run_id",
      [importId, reviewerId],
    );
    await client.query("commit");
    inTransaction = false;
    return result.rows[0].run_id;
  } catch (error) {
    if (inTransaction) await client.query("rollback").catch(() => {});
    throw error;
  }
}

async function runRace(iteration) {
  const setup = await pool.connect();
  const first = await pool.connect();
  const second = await pool.connect();
  try {
    const { tag, reviewerId, journalBatchId, importIds } = await prepareRace(
      setup,
      iteration,
    );
    const [pidA, pidB] = await Promise.all([
      first.query("select pg_backend_pid() as pid"),
      second.query("select pg_backend_pid() as pid"),
    ]);
    assert.notEqual(
      pidA.rows[0].pid,
      pidB.rows[0].pid,
      "workers must use independent PostgreSQL sessions",
    );

    const barrier = makeBarrier(2);
    const workers = [
      () => reconcileWorker(first, importIds[0], reviewerId, barrier),
      () => reconcileWorker(second, importIds[1], reviewerId, barrier),
    ];
    const launchOrder = iteration % 2 === 0 ? workers : [...workers].reverse();
    const outcomes = await Promise.allSettled(
      launchOrder.map((worker) => worker()),
    );
    const failures = outcomes.filter(
      (outcome) => outcome.status === "rejected",
    );
    assert.equal(
      failures.length,
      0,
      `both concurrent reconciliation calls must complete: ${failures.map((failure) => failure.reason?.stack ?? failure.reason).join("\n")}`,
    );

    const rows = await setup.query(
      `select rr.import_id, rr.result_code, rr.result_status, rr.journal_batch_id, rr.run_id
       from public.settlement_reconciliation_results rr
       where rr.import_id = any($1::uuid[])
       order by rr.import_id`,
      [importIds],
    );
    assert.equal(
      rows.rowCount,
      2,
      "each imported report must persist exactly one immutable reconciliation result",
    );
    const matches = rows.rows.filter(
      (row) => row.result_code === "matched_payment",
    );
    const duplicates = rows.rows.filter(
      (row) => row.result_code === "duplicate_reference",
    );
    assert.equal(
      matches.length,
      1,
      "exactly one concurrent import must retain the matched_payment result",
    );
    assert.equal(
      duplicates.length,
      1,
      "the other concurrent import must persist duplicate_reference",
    );
    assert.equal(matches[0].result_status, "matched");
    assert.equal(
      matches[0].journal_batch_id,
      journalBatchId,
      "the sole match must retain the target journal batch",
    );
    assert.equal(duplicates[0].result_status, "exception");
    assert.equal(
      duplicates[0].journal_batch_id,
      null,
      "duplicate_reference must never retain a journal link",
    );

    const links = await setup.query(
      `select count(*)::int as count from public.settlement_reconciliation_results
       where journal_batch_id = $1 and result_status = 'matched'`,
      [journalBatchId],
    );
    assert.equal(
      links.rows[0].count,
      1,
      "the posted journal must be linked by at most one matched result",
    );

    for (let index = 0; index < importIds.length; index += 1) {
      const retry = await setup.query(
        "select public.reconcile_settlement_import($1::uuid, $2::uuid) as run_id",
        [importIds[index], reviewerId],
      );
      const original = rows.rows.find(
        (row) => row.import_id === importIds[index],
      );
      assert.equal(
        retry.rows[0].run_id,
        original.run_id,
        "retry must return the immutable original run id",
      );
    }

    // The two worker connections must remain usable after COMMIT; a transaction
    // error that was swallowed by application code must not leave either aborted.
    await Promise.all([first.query("select 1"), second.query("select 1")]);
    console.log(
      `PASS race ${iteration}/${rounds}: ${tag} (one match, one duplicate_reference, retries stable)`,
    );
  } finally {
    first.release();
    second.release();
    setup.release();
  }
}

try {
  await pool.query("select 1");
  for (let iteration = 1; iteration <= rounds; iteration += 1) {
    await runRace(iteration);
  }
  console.log(
    `PASS: ${rounds} true two-session settlement reconciliation races on PostgreSQL; no live provider processing enabled.`,
  );
} catch (error) {
  console.error(
    "FAIL: Phase 4D2 two-session reconciliation concurrency test",
    error,
  );
  process.exitCode = 1;
} finally {
  await pool.end();
}
