import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { validateHostedRelease } from "./hosted-release-policy.mjs";

const run = (exe, ...args) => execFileSync(exe, args, { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 }).trim();
const git = (...args) => run("git", ...args);
const api = path => {
  const pages = [];
  for (let page = 1; ; page++) {
    const separator = path.includes("?") ? "&" : "?";
    const result = JSON.parse(run("curl", "-q", "--fail", "--silent", "--show-error", "--location",
      "--header", "Accept: application/vnd.github+json",
      `https://api.github.com/repos/zachthinks/ZLaunch/${path}${separator}page=${page}`));
    pages.push(result);
    if (!Array.isArray(result) || result.length < 100) return pages;
  }
};
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
const status = api(`commits/${commit}/statuses?per_page=100`).flat()
  .find(item => item.context === "zlaunch/stable-verified");
const runID = status?.target_url?.match(/^https:\/\/github\.com\/zachthinks\/ZLaunch\/actions\/runs\/(\d+)$/)?.[1];
const workflowRun = runID ? api(`actions/runs/${runID}`)[0] : undefined;
const releases = api("releases?per_page=100").flat();
const tag = `refs/tags/v${metadata.version}`;
const eligible = validateHostedRelease({ metadata, commit, status, workflowRun, releases,
  remoteHead: git("ls-remote", "origin", "refs/heads/custom/main").split(/\s/)[0],
  tagRefs: git("ls-remote", "origin", tag, `${tag}^{}`), promotionRunID,
  allowSkip: process.env.GITHUB_EVENT_NAME === "workflow_run" && process.argv.includes("--skip-ineligible") });
if (eligible) git("merge-base", "--is-ancestor", metadata.upstream_commit, commit);
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT,
  `eligible=${eligible}\ncommit=${commit}\npromotion_run_id=${runID ?? ""}\n`);
console.log(eligible ? `Eligible hosted release ${metadata.version} at ${commit}; promotion run ${runID}.`
  : "No new eligible stable promotion; publication skipped.");
