import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const allowedAdvisories = new Map([
  [
    "GHSA-VFJ7-8CJW-P6XM",
    {
      expiresAt: "2026-11-12T00:00:00.000Z",
      patchFile: "patches/braces@3.0.3.patch",
      regressionTest: "tests/security/braces-depth.test.ts",
      rationale: "The upstream package has no patched release; Web-Temify patches the parser depth and regression-tests the attack shape.",
    },
  ],
]);

function fail(message) {
  console.error(`Dependency audit failed: ${message}`);
  process.exit(1);
}

function advisoryId(value) {
  const text = [
    value?.github_advisory_id,
    value?.url,
    value?.title,
    value?.name,
  ]
    .filter(Boolean)
    .join(" ");
  return text.match(/GHSA-[0-9a-z-]+/i)?.[0]?.toUpperCase() ?? null;
}

function severity(value) {
  const rank = { low: 1, moderate: 2, medium: 2, high: 3, critical: 4 };
  return rank[String(value ?? "").toLowerCase()] ?? 0;
}

const result = spawnSync("pnpm", ["audit", "--json"], {
  encoding: "utf8",
  maxBuffer: 20 * 1024 * 1024,
});
const raw = [result.stdout, result.stderr].filter(Boolean).join("\n");
const start = raw.indexOf("{");
const end = raw.lastIndexOf("}");
if (start < 0 || end <= start) {
  fail(`pnpm audit did not return parseable JSON (exit ${result.status}).`);
}

let report;
try {
  report = JSON.parse(raw.slice(start, end + 1));
} catch (error) {
  fail(`could not parse pnpm audit JSON: ${String(error)}`);
}

const findings = [];
if (report.advisories && typeof report.advisories === "object") {
  for (const advisory of Object.values(report.advisories)) {
    findings.push({
      id: advisoryId(advisory),
      severity: advisory.severity,
      package: advisory.module_name ?? advisory.name ?? "unknown",
      title: advisory.title ?? "security advisory",
      url: advisory.url ?? "",
    });
  }
} else if (report.vulnerabilities && typeof report.vulnerabilities === "object") {
  for (const [name, vulnerability] of Object.entries(report.vulnerabilities)) {
    const via = Array.isArray(vulnerability.via) ? vulnerability.via : [];
    const advisoryObjects = via.filter((item) => item && typeof item === "object");
    if (advisoryObjects.length) {
      for (const advisory of advisoryObjects) {
        findings.push({
          id: advisoryId(advisory),
          severity: advisory.severity ?? vulnerability.severity,
          package: name,
          title: advisory.title ?? advisory.name ?? "security advisory",
          url: advisory.url ?? "",
        });
      }
    } else if (severity(vulnerability.severity) >= 3) {
      findings.push({
        id: advisoryId(vulnerability),
        severity: vulnerability.severity,
        package: name,
        title: "unclassified package vulnerability",
        url: vulnerability.url ?? "",
      });
    }
  }
} else {
  fail("unrecognized pnpm audit JSON schema; refusing to pass without reviewing it.");
}

const blocking = [];
const allowed = new Set();
for (const finding of findings) {
  if (severity(finding.severity) < 3) continue;
  const exception = finding.id ? allowedAdvisories.get(finding.id) : null;
  if (!exception) {
    blocking.push(finding);
    continue;
  }

  if (Date.now() >= Date.parse(exception.expiresAt)) {
    blocking.push({ ...finding, title: `${finding.title} (exception expired)` });
    continue;
  }

  const patchExists = existsSync(exception.patchFile);
  const testExists = existsSync(exception.regressionTest);
  const patch = patchExists ? readFileSync(exception.patchFile, "utf8") : "";
  const test = testExists ? readFileSync(exception.regressionTest, "utf8") : "";
  const workspace = readFileSync("pnpm-workspace.yaml", "utf8");
  if (
    !patch.includes("maximum depth") ||
    !test.includes("101") ||
    !test.includes("maximum depth") ||
    !workspace.includes("braces@3.0.3: patches/braces@3.0.3.patch")
  ) {
    blocking.push({ ...finding, title: `${finding.title} (required local patch/test missing)` });
    continue;
  }
  allowed.add(finding.id);
}

if (blocking.length) {
  console.error("Blocking high/critical advisories:");
  for (const item of blocking) {
    console.error(`- [${item.severity}] ${item.package}: ${item.title} (${item.id ?? "no advisory ID"}) ${item.url}`);
  }
  process.exit(1);
}

if (allowed.size) {
  for (const id of allowed) {
    const exception = allowedAdvisories.get(id);
    console.warn(`TIME-BOUNDED LOCAL PATCH: ${id}; expires ${exception.expiresAt}; ${exception.rationale}`);
  }
}

console.log("Dependency audit passed: no unmitigated high/critical advisories remain.");
