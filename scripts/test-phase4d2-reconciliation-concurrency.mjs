import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import pg from "pg";

const { Pool } = pg;
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
¶»§q«^