import assert from "node:assert/strict";
import { validatePublication } from "../publication-policy.mjs";

const valid = {
  metadata: { repository: "zachthinks/ZLaunch", team: "FVY9AS28CU", version: "0.1.7",
    upstream_tag: "v0.11.19", upstream_commit: "a".repeat(40), upstream_prerelease: false },
  commit: "b".repeat(40), latestVersion: "0.1.6",
  status: { context: "zlaunch/stable-verified", state: "success", creator: { login: "github-actions[bot]" },
    target_url: "https://github.com/zachthinks/ZLaunch/actions/runs/123" },
  workflowRun: { id: 123, repository: { full_name: "zachthinks/ZLaunch" },
    path: ".github/workflows/custom-sync.yml", event: "schedule", status: "completed", conclusion: "success" }
};
validatePublication(valid);
const reject = mutate => {
  const candidate = structuredClone(valid);
  mutate(candidate);
  assert.throws(() => validatePublication(candidate));
};
reject(x => x.metadata.upstream_tag = "v0.11.20-beta.119");
reject(x => x.metadata.upstream_prerelease = true);
reject(x => x.metadata.team = "OTHERTEAM");
reject(x => x.metadata.repository = "abue-ammar/tinycast");
reject(x => x.metadata.version = "0.1.6");
reject(x => x.latestVersion = "0.2.0");
reject(x => x.status.state = "failure");
reject(x => x.status.creator.login = "someone-else");
reject(x => x.status.target_url += "4");
reject(x => x.workflowRun.conclusion = "cancelled");
reject(x => x.workflowRun.status = "in_progress");
reject(x => x.workflowRun.path = ".github/workflows/custom-release.yml");
reject(x => x.workflowRun.event = "pull_request");
reject(x => x.workflowRun.repository.full_name = "someone/ZLaunch");
reject(x => x.commit = "main");
console.log("Publication policy rejects beta, wrong identity, stale versions, failed/incomplete and unrelated checks.");
