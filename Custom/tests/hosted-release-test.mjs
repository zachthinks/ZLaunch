import assert from "node:assert/strict";
import { validateHostedRelease } from "../hosted-release-policy.mjs";

const commit = "a".repeat(40);
const fixture = () => ({
  metadata: { repository: "zachthinks/ZLaunch", team: "FVY9AS28CU", version: "0.1.10",
    upstream_prerelease: false, upstream_tag: "v0.11.20", upstream_commit: "b".repeat(40) },
  commit, remoteHead: commit, promotionRunID: "123", allowSkip: true, releases: [], tagRefs: "",
  status: { context: "zlaunch/stable-verified", state: "success", creator: { login: "github-actions[bot]" },
    target_url: "https://github.com/zachthinks/ZLaunch/actions/runs/123" },
  workflowRun: { id: 123, repository: { full_name: "zachthinks/ZLaunch" },
    path: ".github/workflows/custom-sync.yml", event: "schedule", status: "completed", conclusion: "success" },
});
function rejects(change) {
  const input = fixture();
  change(input);
  assert.throws(() => validateHostedRelease(input));
}
assert.equal(validateHostedRelease(fixture()), true);
for (const change of [x => x.status = undefined, x => x.promotionRunID = "124"]) {
  const input = fixture(); change(input);
  assert.equal(validateHostedRelease(input), false, "No-op sync must not publish an older promotion.");
  input.allowSkip = false;
  assert.throws(() => validateHostedRelease(input));
}
rejects(x => x.remoteHead = "c".repeat(40));
rejects(x => x.status.state = "failure");
rejects(x => x.status.creator.login = "someone");
rejects(x => x.workflowRun.status = "in_progress");
rejects(x => x.workflowRun.conclusion = "failure");
rejects(x => x.workflowRun.event = "pull_request");
rejects(x => x.workflowRun.path = ".github/workflows/custom-checks.yml");
rejects(x => x.workflowRun.repository.full_name = "someone/ZLaunch");
rejects(x => x.metadata.upstream_prerelease = true);
rejects(x => x.metadata.team = "WRONG");
rejects(x => x.metadata.version = "0.1.10-beta");
rejects(x => x.tagRefs = `${"c".repeat(40)}\trefs/tags/v0.1.10`);
rejects(x => x.releases = [{ tag_name: "v0.1.11", draft: false, prerelease: false }]);
const published = { tag_name: "v0.1.10", draft: false, prerelease: false,
  assets: ["ZLaunch-0.1.10.dmg", "ZLaunch-0.1.10.zip", "SHA256SUMS"].map(name => ({ name, size: 100 })) };
const repeated = fixture(); repeated.releases = [published];
assert.equal(validateHostedRelease(repeated), false, "A complete release is an idempotent skip.");
repeated.allowSkip = false;
assert.throws(() => validateHostedRelease(repeated), "A manual retry cannot overwrite a release.");
rejects(x => x.releases = [{ ...published, draft: true }]);
rejects(x => x.releases = [{ ...published, assets: [] }]);
rejects(x => x.releases = [{ ...published, assets: published.assets.map(asset => ({ ...asset, size: 0 })) }]);
console.log("Hosted release policy: exact successful promotion, stale/failed/untrusted rejection, stable-only, no overwrite and idempotent skip passed.");
