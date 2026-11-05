import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = mkdtempSync(join(tmpdir(), "zlaunch-migration-policy-"));
const repo = join(root, "repo");
const env = { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };
const run = (command, args, cwd = repo) => {
  const result = spawnSync(command, args, { cwd, env, encoding: "utf8" });
  assert.ifError(result.error);
  return result;
};
const git = (...args) => {
  const result = run("git", ["-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", ...args]);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
const check = (status, message, cwd = repo) => {
  const result = run("bash", ["Scripts/check-migrations.sh"], cwd);
  assert.equal(result.status, status, result.stdout + result.stderr);
  if (message) assert.match(result.stderr, message);
};
const commit = () => {
  git("add", ".");
  git("commit", "-qm", "fixture");
};
const release = (version, repository = "zachthinks/ZLaunch") => {
  writeFileSync(join(repo, "Custom/release.json"), JSON.stringify({ version, repository }));
  commit();
};

try {
  for (const path of ["Scripts", "Tinycast/Migrations", "docs", "Custom"]) {
    mkdirSync(join(repo, path), { recursive: true });
  }
  copyFileSync(fileURLToPath(new URL("../../Scripts/check-migrations.sh", import.meta.url)),
    join(repo, "Scripts/check-migrations.sh"));
  writeFileSync(join(repo, "Tinycast/Migrations/ExampleMigration.swift"), "struct ExampleMigration {}\n");
  writeFileSync(join(repo, "docs/migrations.md"), "| `ExampleMigration` | fixture |\n");
  git("init", "-q");
  git("config", "user.name", "Migration policy fixture");
  git("config", "user.email", "migration-fixture@example.invalid");
  commit();
  git("tag", "v0.12.8");
  check(0);

  release("0.1.1", "other/repository");
  git("tag", "v0.1.1");
  check(0);
  release("0.1.2");
  git("tag", "v0.1.3");
  git("tag", "v0.1.2-beta.1");
  check(0);
  writeFileSync(join(repo, "Custom/release.json"), "invalid json");
  commit();
  git("tag", "v0.1.4");
  check(0);

  writeFileSync(join(repo, "docs/migrations.md"), "No live migration rows.\n");
  check(1, /ExampleMigration has no row/);
  git("restore", "docs/migrations.md");

  release("0.1.5");
  git("tag", "-a", "v0.1.5", "-m", "custom stable release");
  check(1, /ExampleMigration shipped in v0\.1\.5/);

  const shallow = join(root, "shallow");
  git("clone", "-q", "--depth=1", `file://${repo}`, shallow);
  check(1, /needs full history/, shallow);

  rmSync(join(repo, "Tinycast/Migrations/ExampleMigration.swift"));
  check(0);
  console.log("Migration policy distinguishes custom stable releases, upstream tags, prereleases and shallow history.");
} finally {
  rmSync(root, { recursive: true, force: true });
}
