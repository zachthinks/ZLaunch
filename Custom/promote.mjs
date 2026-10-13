import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const run = (exe, ...args) => execFileSync(exe, args, { encoding: "utf8" }).trim();
const git = (...args) => run("git", ...args);
const { CHECKED_COMMIT: commit, SYNC_BASE: base, GITHUB_REPOSITORY: repository,
  GITHUB_RUN_ID: runID, GITHUB_EVENT_NAME: event } = process.env;
assert.equal(repository, "zachthinks/ZLaunch");
assert.ok(["schedule", "workflow_dispatch"].includes(event));
assert.match(commit ?? "", /^[a-f0-9]{40}$/);
assert.match(base ?? "", /^[a-f0-9]{40}$/);
assert.match(runID ?? "", /^\d+$/);
assert.equal(git("rev-parse", "HEAD"), commit);
assert.equal(git("status", "--porcelain"), "");
const metadata = JSON.parse(readFileSync("Custom/release.json", "utf8"));
assert.equal(metadata.repository, repository);
assert.equal(metadata.team, "FVY9AS28CU");
assert.equal(metadata.upstream_prerelease, false);
assert.match(metadata.upstream_tag, /^v\d+\.\d+\.\d+$/);
git("fetch", "origin", "custom/main");
assert.equal(git("rev-parse", "FETCH_HEAD"), base, "Main changed during checks; regenerate and recheck.");
git("merge-base", "--is-ancestor", base, commit);
// A normal fast-forward push refuses a concurrent, divergent update. Never force.
git("push", "origin", `${commit}:refs/heads/custom/main`);
run("gh", "api", `repos/${repository}/statuses/${commit}`, "-f", "state=success",
  "-f", "context=zlaunch/stable-verified", "-f", "description=Stable candidate passed checks and was promoted",
  "-f", `target_url=https://github.com/${repository}/actions/runs/${runID}`);
console.log(`Promoted checked stable candidate ${commit}. Local publication waits for this entire run to succeed.`);
