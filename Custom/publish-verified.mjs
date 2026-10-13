// Run only in a dedicated clean custom/main checkout; never borrow the working repository.
// Default is read-only eligibility inspection. --publish also requires local opt-in.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { repository, validatePublication } from "./publication-policy.mjs";

const run = (exe, ...args) => execFileSync(exe, args, { encoding: "utf8" }).trim();
const git = (...args) => run("git", ...args);
const api = path => JSON.parse(run("gh", "api", `repos/${repository}/${path}`));
const publish = process.argv.includes("--publish");
assert.ok(process.argv.slice(2).every(arg => arg === "--publish"));
if (publish) assert.equal(process.env.ZLAUNCH_AUTOPUBLISH, "1", "Local publisher is not activated.");
assert.equal(git("branch", "--show-current"), "custom/main");
assert.equal(git("status", "--porcelain"), "", "Use a clean dedicated publication checkout.");
assert.ok([`https://github.com/${repository}.git`, `git@github.com:${repository}.git`]
  .includes(git("remote", "get-url", "origin")), "Unexpected publication remote.");
const commit = git("rev-parse", "HEAD");
const remoteHead = git("ls-remote", "origin", "refs/heads/custom/main").split(/\s/)[0];
assert.equal(remoteHead, commit, "Checkout must exactly match remote custom/main.");
const metadata = JSON.parse(readFileSync("Custom/release.json", "utf8"));
const releases = JSON.parse(run("gh", "api", "--paginate", "--slurp", `repos/${repository}/releases?per_page=100`)).flat();
assert.ok(!releases.some(item => item.tag_name === `v${metadata.version}`),
  "Version already exists (including drafts): do not overwrite or create a duplicate.");
const status = api(`commits/${commit}/statuses?per_page=100`)
  .find(item => item.context === "zlaunch/stable-verified");
assert.ok(status, "No successful promotion attestation for this exact commit.");
const match = status.target_url?.match(/^https:\/\/github\.com\/zachthinks\/ZLaunch\/actions\/runs\/(\d+)$/);
assert.ok(match, "Invalid check provenance URL.");
const workflowRun = api(`actions/runs/${match[1]}`);
const latestVersion = releases.filter(item => !item.draft && !item.prerelease && /^v\d+\.\d+\.\d+$/.test(item.tag_name))
  .map(item => item.tag_name.slice(1)).sort((a, b) => {
    const aa = a.split(".").map(Number), bb = b.split(".").map(Number);
    return bb[0] - aa[0] || bb[1] - aa[1] || bb[2] - aa[2];
  })[0];
validatePublication({ metadata, commit, status, workflowRun, latestVersion });
git("merge-base", "--is-ancestor", metadata.upstream_commit, commit);
console.log(`Eligible: ZLaunch ${metadata.version} at ${commit}; checks ${status.target_url}`);
if (publish) {
  assert.equal(process.env.NOTARY_PROFILE, "ZLaunch-Local", "Use the existing local profile; do not create credentials.");
  // publish.sh owns the common lock so manual publication respects it too.
  execFileSync("./Custom/publish.sh", { stdio: "inherit", env: { ...process.env, CHECKS_VERIFIED: "1" } });
}
