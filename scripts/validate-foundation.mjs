import { readFile, access } from "node:fs/promises";
import { constants } from "node:fs";
const requiredFiles = [
  "README.md",
  "package.json",
  "tsconfig.json",
  ".env.example",
  "docs/architecture/overview.md",
  "docs/architecture/repository-structure.md",
  "docs/architecture/domain-boundaries.md",
  "docs/roadmap/phase-gates.md",
  "docs/security/security-baseline.md",
  "docs/security/threat-model.md",
  "docs/quality/testing-strategy.md",
  "src/app/layout.tsx",
  "src/app/page.tsx",
];
const failures = [];
for (const path of requiredFiles) {
  try {
    await access(path, constants.R_OK);
    if (!(await readFile(path, "utf8")).trim())
      failures.push(path + ": empty file");
  } catch {
    failures.push(path + ": missing or unreadable");
  }
}
const pkg = JSON.parse(await readFile("package.json", "utf8"));
if (!pkg.scripts?.["check:foundation"])
  failures.push("package.json: missing check:foundation script");
if (!pkg.scripts?.typecheck)
  failures.push("package.json: missing typecheck script");
const env = await readFile(".env.example", "utf8");
if (/^(?!#).*?(sk_live_|service_role_[A-Za-z0-9]{10,})/m.test(env))
  failures.push(".env.example: appears to contain a credential");
if (failures.length) {
  console.error("Foundation validation failed:");
  for (const item of failures) console.error("- " + item);
  process.exitCode = 1;
} else
  console.log(
    "Foundation validation passed: " +
      requiredFiles.length +
      " required files and baseline manifest checks.",
  );
