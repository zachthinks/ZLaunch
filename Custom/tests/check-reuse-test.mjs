import assert from "node:assert/strict";
import { reusePushChecks } from "../check-reuse.mjs";

const commit = "a".repeat(40);
const run = () => ({ id: 123, run_attempt: 1, head_sha: commit, head_branch: "custom/main", event: "push",
  path: ".github/workflows/custom-checks.yml", status: "completed", conclusion: "success",
  repository: { full_name: "zachthinks/ZLaunch" }, head_repository: { full_name: "zachthinks/ZLaunch" } });
const job = () => ({ name: "verify", run_id: 123, run_attempt: 1, head_sha: commit, conclusion: "success",
  steps: ["Confirm checkout identity", "Run ./Custom/check.sh"].map(name => ({ name, conclusion: "success" })) });
async function scenario({ runs = [run()], jobs = [job()], fresh = run(), error, discovery = 60_000,
  timeout = 120_000 } = {}) {
  let tick = 0, reads = 0;
  const requests = [];
  const result = await reusePushChecks({ commit, discovery, timeout, now: () => tick,
    wait: async ms => { tick += ms; }, api: async path => {
      requests.push(path);
      if (error) throw error;
      if (path.startsWith("actions/workflows/")) {
        const rows = typeof runs === "function" ? runs(reads++) : runs;
        return [{ workflow_runs: rows }];
      }
      if (path.includes("/attempts/")) return [{ total_count: jobs.length, jobs }];
      return [fresh];
    } });
  return { result, requests, tick };
}
assert.deepEqual((await scenario()).result, { reused: true, runID: 123, attempt: 1 });
let checked = await scenario({ runs: [] });
assert.equal(checked.result.reused, false);
assert.equal(checked.tick, 60_000);
checked = await scenario({ runs: i => i ? [run()] : [{ ...run(), status: "in_progress", conclusion: null }] });
assert.equal(checked.result.reused, true);
assert.equal(checked.tick, 30_000);
for (const change of [r => r.head_sha = "b".repeat(40)]) {
  const row = run(); change(row);
  assert.equal((await scenario({ runs: [row] })).result.reused, false);
}
for (const change of [r => r.repository.full_name = "other/repo", r => r.head_repository.full_name = "fork/repo",
  r => r.event = "pull_request", r => r.path = ".github/workflows/other.yml", r => r.head_branch = "other",
  r => r.conclusion = "failure", r => r.conclusion = "cancelled", r => r.conclusion = "skipped"]) {
  const row = run(); change(row);
  await assert.rejects(scenario({ runs: [row] }));
}
for (const change of [j => j.head_sha = "b".repeat(40), j => j.run_attempt = 2, j => j.run_id = 456,
  j => j.name = "other", j => j.conclusion = "skipped", j => j.steps = [],
  j => j.steps[0].conclusion = "skipped", j => j.steps[1].conclusion = "failure"]) {
  const row = job(); change(row);
  await assert.rejects(scenario({ jobs: [row] }));
}
await assert.rejects(scenario({ error: new Error("HTTP 403") }), /HTTP 403/);
await assert.rejects(scenario({ runs: [{ ...run(), status: "in_progress", conclusion: null }] }), /20 minutes/);
await assert.rejects(scenario({ fresh: { ...run(), run_attempt: 2, status: "in_progress" } }), /20 minutes/);
await assert.rejects(scenario({ fresh: { ...run(), conclusion: "failure" } }));
const newest = { ...run(), id: 124, conclusion: "failure" };
await assert.rejects(scenario({ runs: [run(), newest] }), /Push checks failed/);
console.log("Check reuse: exact SHA/repository/workflow/attempt, real completed checks, no stale/failed/skipped reuse, bounded waits and API failures passed.");
