import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { githubReleaseAPI } from "./github-release-api.mjs";
import { validateExistingHostedRelease, validateHostedRelease } from "./hosted-release-policy.mjs";

const run = (exe, ...args) => execFileSync(exe, args, { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 }).trim();
const git = (...args) => run("git", ...args);
const api = githubReleaseAPI();
assert.equal(process.env.GITHUB_REPOSITORY, "zachthinks/ZLaunch");
assert.equal(process.env.GITHUB_REF, "refs/heads/custom/main");
assert.ok(["workflow_dispatch", "workflow_run"].includes(process.env.GITHUB_EVENT_NAME));
const commit = process.env.EXPECTED_COMMIT;
assert.match(commit ?? "", /^[a-f0-9]{40}$/);
assert.equal(commit, process.env.GITHUB_SHA);
assert.equal(git("rev-parse", "HEAD"), commit);
assert.equal(git("status", "--porcelain"), "");
const promotionRunID = process.env.PROMOTION_RUN_ID;
if (promotionRunID) assert.match(promotionRunID, /^\d+$/);
if (process.env.GITHUB_EVENT_NAME === "workflow_run") assert.ok(promotionRunID);
const metadata = JSON.parse(readFileSync("Custom/release.json", "utf8"));
const allowSkip = process.env.GITHUB_EVENT_NAME === "workflow_run" && process.argv.includes("--skip-ineligible");
const remoteHead = git("ls-remote", "origin", "refs/heads/custom/main").split(/\s/)[0];
assert.equal(remoteHead, commit, "Main changed; check the new commit before publishing.");
const releasePages = await api("releases?per_page=100");
assert.ok(releasePages.every(Array.isArray), "Invalid release list response.");
const releases = releasePages.flat();
assert.ok(releases.every(release => typeof release.tag_name === "string"), "Invalid release response.");
let eligible = false;
let runID;
if (!validateExistingHostedRelease({ metadata, releases, allowSkip })) {
  const statusPages = await api(`commits/${commit}/statuses?per_page=100`);
  assert.ok(statusPages.every(Array.isArray), "Invalid commit statuses list response.");
  const statuses = statusPages.flat();
  assert.ok(statuses.every(item => typeof item.context === "string"), "Invalid commit statuses response.");
  const status = statuses.find(item => item.context === "zlaunch/stable-verified");
  runID = status?.target_url?.match(/^https:\/\/github\.com\/zachthinks\/ZLaunch\/actions\/runs\/(\d+)$/)?.[1];
  const matches = runID && (!promotionRunID || runID === promotionRunID);
  const workflowRun = matches ? (await api(`actions/runs/${runID}`))[0] : undefined;
  const tag = `refs/tags/v${metadata.version}`;
  eligible = validateHostedRelease({ metadata, commit, status, workflowRun, releases, remoteHead,
    tagRefs: git("ls-remote", "origin", tag, `${tag}^{}`), promotionRunID, allowSkip });
}
if (eligible) git("merge-base", "--is-ancestor", metadata.upstream_commit, commit);
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT,
  `eligible=${eligible}\ncommit=${commit}\npromotion_run_id=${runID ?? ""}\n`);
console.log(eligible ? `Eligible hosted release ${metadata.version} at ${commit}; promotion run ${runID}.`
  : "No new eligible stable promotion; publication skipped.");
