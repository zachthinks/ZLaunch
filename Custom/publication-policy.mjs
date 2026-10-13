import assert from "node:assert/strict";

export const repository = "zachthinks/ZLaunch";
export function validatePublication({ metadata, commit, status, workflowRun, latestVersion }) {
  assert.match(commit, /^[a-f0-9]{40}$/);
  assert.equal(metadata.repository, repository);
  assert.equal(metadata.team, "FVY9AS28CU");
  assert.equal(metadata.upstream_prerelease, false);
  assert.match(metadata.upstream_tag, /^v\d+\.\d+\.\d+$/);
  assert.match(metadata.upstream_commit, /^[a-f0-9]{40}$/);
  assert.match(metadata.version, /^\d+\.\d+\.\d+$/);
  assert.equal(status.context, "zlaunch/stable-verified");
  assert.equal(status.state, "success");
  assert.equal(status.creator?.login, "github-actions[bot]");
  assert.equal(status.target_url, `https://github.com/${repository}/actions/runs/${workflowRun.id}`);
  assert.equal(workflowRun.repository?.full_name, repository);
  assert.equal(workflowRun.path, ".github/workflows/custom-sync.yml");
  assert.ok(["schedule", "workflow_dispatch"].includes(workflowRun.event));
  assert.equal(workflowRun.status, "completed");
  assert.equal(workflowRun.conclusion, "success");
  if (latestVersion) {
    assert.match(latestVersion, /^\d+\.\d+\.\d+$/);
    const next = metadata.version.split(".").map(Number);
    const previous = latestVersion.split(".").map(Number);
    const differing = next.findIndex((part, index) => part !== previous[index]);
    assert.ok(differing >= 0 && next[differing] > previous[differing], "Release version must increase.");
  }
}
