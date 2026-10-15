import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verifyWorkflowPolicy } from "../workflow-policy.mjs";

const names = ["custom-checks.yml", "custom-release.yml", "custom-signing-validation.yml", "custom-sync.yml"];
const workflows = Object.fromEntries(names.map((name) => [name, readFileSync(`.github/workflows/${name}`, "utf8")]));
verifyWorkflowPolicy(workflows);
function rejects(name, from, to) {
  const source = workflows[name];
  let index = source.indexOf(from);
  assert.ok(index >= 0, "The mutation must change the workflow.");
  while (index >= 0) {
    const changed = source.slice(0, index) + to + source.slice(index + from.length);
    assert.throws(() => verifyWorkflowPolicy({ ...workflows, [name]: changed }),
      name + ": mutation at " + index + " must be rejected");
    index = source.indexOf(from, index + from.length);
  }
}
rejects("custom-checks.yml", "runs-on: macos-26", "runs-on: macos-26-xlarge");
rejects("custom-sync.yml", "runs-on: ubuntu-latest", "runs-on: paid-linux");
for (const name of names) {
  rejects(name, "if: github.event.repository.private == false", "if: true");
  const checkout = ["custom-release.yml", "custom-signing-validation.yml"].includes(name)
    ? "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1" : "actions/checkout@v7";
  rejects(name, checkout, "actions/upload-artifact@v7");
  rejects(name, checkout, "actions/cache@v4");
}
rejects("custom-sync.yml", "github.event.repository.private == false && needs.sync.outputs.candidate != ''",
  "needs.sync.outputs.candidate != ''");
rejects("custom-checks.yml", "  verify:", "  unreviewed:\n    runs-on: macos-26\n  verify:");
rejects("custom-sync.yml", "needs: [sync, checks]", "needs: [sync]");
rejects("custom-sync.yml", "needs.checks.result == 'success'", "needs.checks.result != 'cancelled'");
rejects("custom-sync.yml", "CHECKED_COMMIT: ${{ needs.sync.outputs.candidate }}", "CHECKED_COMMIT: main");
assert.throws(() => verifyWorkflowPolicy({ ...workflows, "custom-unreviewed.yml": workflows[names[0]] }));
console.log("Workflow policy rejects paid runner labels, private jobs, caches, artifacts, and unreviewed jobs.");

rejects("custom-release.yml", "github.ref == 'refs/heads/custom/main'", "true");
rejects("custom-release.yml", "github.event_name == 'workflow_dispatch'", "true");
rejects("custom-release.yml", "vars.ZLAUNCH_HOSTED_RELEASE_ENABLED == 'true'", "true");
rejects("custom-release.yml", "needs: preflight", "needs: []");
rejects("custom-release.yml", "needs.preflight.result == 'success'", "true");
rejects("custom-release.yml", "environment: zlaunch-release", "environment: unprotected");
rejects("custom-release.yml", "ref: ${{ github.sha }}", "ref: custom/main");
rejects("custom-release.yml", "persist-credentials: false", "persist-credentials: true");
rejects("custom-release.yml", "if: always()", "if: success()");

for (const name of ["custom-release.yml", "custom-signing-validation.yml"]) {
  rejects(name, "permissions:\n  contents: read", "permissions:\n  contents: write");
  rejects(name, "  workflow_dispatch:", "  push:");
  rejects(name, "ref: ${{ github.sha }}", "ref: custom/main");
  rejects(name, "persist-credentials: false", "persist-credentials: true");
  rejects(name, "git fetch origin custom/main", "git status");
  rejects(name, "git rev-parse FETCH_HEAD", "git rev-parse HEAD");
  rejects(name, "security delete-keychain", "echo cleanup");
  rejects(name, "needs.preflight.result == 'success'", "true");
  rejects(name, "if: always()", "if: success()");
}
rejects("custom-release.yml", "node Custom/verify-release-state.mjs", "echo skipped");
rejects("custom-release.yml", "NOTARY_KEYCHAIN: ${{ runner.temp }}/zlaunch.keychain-db", "NOTARY_KEYCHAIN: wrong");
for (const guard of ["github.ref == 'refs/heads/custom/main'", "github.event_name == 'workflow_dispatch'",
  "vars.ZLAUNCH_HOSTED_VALIDATION_ENABLED == 'true'", "inputs.confirm_signing_validation == true"]) {
  rejects("custom-signing-validation.yml", guard, "true");
}
rejects("custom-signing-validation.yml", "default: false", "default: true");
rejects("custom-signing-validation.yml", "test \"$EXPECTED_COMMIT\" = \"$GITHUB_SHA\"", "true");
rejects("custom-signing-validation.yml", "run: ./Custom/validate-signing.sh", "run: ./Custom/publish.sh");
rejects("custom-signing-validation.yml", "exit \"$CLEANUP_STATUS\"", "exit 0");
console.log("Every hosted job guard, checkout, fresh-main check and cleanup mutation is rejected.");

for (const guard of ["github.event.workflow_run.conclusion == 'success'", "github.event.workflow_run.head_branch == 'custom/main'",
  "needs.preflight.outputs.eligible == 'true'"]) rejects("custom-release.yml", guard, "true");
rejects("custom-release.yml", "workflows: [ZLaunch upstream sync]", "workflows: [ZLaunch checks]");
rejects("custom-release.yml", "types: [completed]", "types: [requested]");
rejects("custom-release.yml", "node Custom/verify-hosted-release.mjs", "echo skipped");
rejects("custom-release.yml", "if: steps.eligibility.outputs.eligible == 'true'", "if: always()");

rejects("custom-sync.yml", "VERIFY_CURRENT_RELEASE: ${{ inputs.verify_current_release }}", "VERIFY_CURRENT_RELEASE: true");
rejects("custom-sync.yml", "node Custom/prepare-custom-release.mjs", "echo skipped");
