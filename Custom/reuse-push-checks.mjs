import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { appendFileSync } from "node:fs";
import { githubReleaseAPI } from "./github-release-api.mjs";
import { reusePushChecks } from "./check-reuse.mjs";

assert.equal(process.env.GITHUB_REPOSITORY, "zachthinks/ZLaunch");
assert.equal(process.env.GITHUB_REF, "refs/heads/custom/main");
const commit = process.env.EXPECTED_CHECK_COMMIT;
assert.match(commit ?? "", /^[a-f0-9]{40}$/);
assert.equal(execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim(), commit);
const result = await reusePushChecks({ commit, api: githubReleaseAPI() });
appendFileSync(process.env.GITHUB_OUTPUT, `reused=${result.reused}\n`);
const summary = result.reused
  ? `Reused full checks for ${commit}: https://github.com/zachthinks/ZLaunch/actions/runs/${result.runID}/attempts/${result.attempt}`
  : `No push check run found for ${commit}; running the full suite once here.`;
console.log(summary);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary + "\n");
