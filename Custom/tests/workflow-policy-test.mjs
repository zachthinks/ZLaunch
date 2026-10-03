import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verifyWorkflowPolicy } from "../workflow-policy.mjs";

const names = ["custom-checks.yml", "custom-release.yml", "custom-sync.yml"];
const workflows = Object.fromEntries(names.map((name) => [name, readFileSync(`.github/workflows/${name}`, "utf8")]));
verifyWorkflowPolicy(workflows);
function rejects(name, from, to) {
  assert.ok(workflows[name].includes(from), "The mutation must change the workflow.");
  assert.throws(() => verifyWorkflowPolicy({ ...workflows, [name]: workflows[name].replace(from, to) }));
}
rejects("custom-checks.yml", "runs-on: macos-26", "runs-on: macos-26-xlarge");
rejects("custom-sync.yml", "runs-on: ubuntu-latest", "runs-on: paid-linux");
for (const name of names) {
  rejects(name, "if: github.event.repository.private == false", "if: true");
  rejects(name, "actions/checkout@v7", "actions/upload-artifact@v7");
  rejects(name, "actions/checkout@v7", "actions/cache@v4");
}
rejects("custom-sync.yml", "github.event.repository.private == false && needs.sync.outputs.candidate != ''",
  "needs.sync.outputs.candidate != ''");
rejects("custom-checks.yml", "  verify:", "  unreviewed:\n    runs-on: macos-26\n  verify:");
assert.throws(() => verifyWorkflowPolicy({ ...workflows, "custom-unreviewed.yml": workflows[names[0]] }));
console.log("Workflow policy rejects paid runner labels, private jobs, caches, artifacts, and unreviewed jobs.");
