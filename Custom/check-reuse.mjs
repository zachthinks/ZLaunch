import assert from "node:assert/strict";

const repository = "zachthinks/ZLaunch";

function validateRun(run, commit) {
  assert.equal(run.head_sha, commit);
  assert.equal(run.repository?.full_name, repository);
  assert.equal(run.head_repository?.full_name, repository);
  assert.equal(run.path, ".github/workflows/custom-checks.yml");
  assert.equal(run.event, "push");
  assert.equal(run.head_branch, "custom/main");
  assert.ok(Number.isSafeInteger(run.id) && run.id > 0);
  assert.ok(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0);
}

export async function reusePushChecks({ commit, api, wait = ms => new Promise(resolve => setTimeout(resolve, ms)),
  now = Date.now, timeout = 20 * 60_000, discovery = 60_000 }) {
  assert.match(commit, /^[a-f0-9]{40}$/);
  const began = now();
  while (now() - began < timeout) {
    const [page] = await api(`actions/workflows/custom-checks.yml/runs?head_sha=${commit}&event=push&branch=custom%2Fmain&per_page=100`);
    assert.ok(Array.isArray(page?.workflow_runs), "Invalid workflow run list.");
    const run = page.workflow_runs.filter(item => item.head_sha === commit)
      .sort((a, b) => b.id - a.id)[0];
    if (!run) {
      if (now() - began >= discovery) return { reused: false };
    } else {
      validateRun(run, commit);
      if (run.status === "completed") {
        assert.equal(run.conclusion, "success", "Push checks failed; inspect or explicitly rerun them.");
        const [page] = await api(`actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
        assert.ok(Array.isArray(page?.jobs) && page.total_count === page.jobs.length,
          "Incomplete check job list; cannot reuse it.");
        const jobs = page.jobs.filter(job => job.name === "verify");
        assert.equal(jobs.length, 1, "Expected one full verification job.");
        const job = jobs[0];
        assert.equal(job.run_id, run.id);
        assert.equal(job.run_attempt, run.run_attempt);
        assert.equal(job.head_sha, commit);
        assert.equal(job.conclusion, "success");
        assert.ok(job.steps?.some(step => step.name === "Confirm checkout identity" && step.conclusion === "success"),
          "Check run did not verify its checkout identity.");
        assert.ok(job.steps?.some(step => step.name === "Run ./Custom/check.sh" && step.conclusion === "success"),
          "Full source checks did not complete successfully.");
        const [fresh] = await api(`actions/runs/${run.id}`);
        validateRun(fresh, commit);
        if (fresh.run_attempt === run.run_attempt && fresh.status === "completed") {
          assert.equal(fresh.conclusion, "success");
          return { reused: true, runID: run.id, attempt: run.run_attempt };
        }
      }
    }
    await wait(30_000);
  }
  throw new Error("Existing push checks did not finish within 20 minutes; no duplicate suite was started.");
}
