import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
test("project manifest is private and has a foundation check", async () => {
  const pkg = JSON.parse(
    await readFile(new URL("../package.json", import.meta.url), "utf8"),
  );
  assert.equal(pkg.private, true);
  assert.equal(typeof pkg.scripts["check:foundation"], "string");
});
test("integration flags are opt-in", async () => {
  const source = await readFile(
    new URL("../src/lib/feature-flags.ts", import.meta.url),
    "utf8",
  );
  assert.match(source, /isEnabled/);
  assert.match(source, /TINLANCE_AGENT_INTEGRATION_ENABLED/);
});
test("starter page says marketplace functions are not live", async () => {
  const source = await readFile(
    new URL("../src/app/page.tsx", import.meta.url),
    "utf8",
  );
  assert.match(source, /not live yet/i);
});
