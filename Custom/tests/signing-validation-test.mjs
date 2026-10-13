import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const script = readFileSync("Custom/validate-signing.sh", "utf8");
const publish = readFileSync("Custom/publish.sh", "utf8");
for (const source of [script, publish]) execFileSync("/bin/bash", ["-n"], { input: source });
for (const name of ["custom-release.yml", "custom-signing-validation.yml"]) {
  const workflow = readFileSync(".github/workflows/" + name, "utf8");
  for (const match of workflow.matchAll(/        run: \|\n((?:          .*\n|\n)+)/g)) {
    execFileSync("/bin/bash", ["-n"], { input: match[1].replace(/^          /gm, "") });
  }
}
assert.equal((publish.match(/node Custom\/verify-release-state.mjs/g) ?? []).length, 2);
assert.ok(publish.lastIndexOf("node Custom/verify-release-state.mjs") < publish.indexOf("gh release create"));
assert.match(publish, /NOTARY_ARGS\+=\(--keychain "\$NOTARY_KEYCHAIN"\)/);
assert.match(publish, /notarytool submit build\/notarize.zip "\$\{NOTARY_ARGS\[@\]\}"/);
assert.ok(!/\bgh\b|Custom\/publish\.sh|Custom\/package\.sh|git push|git tag/.test(script));

const root = mkdtempSync(join(tmpdir(), "zlaunch-signing-fixture-"));
const commit = "b".repeat(40);
const stub = "#!" + process.execPath + "\n" + "\nconst { appendFileSync } = require(\"node:fs\");\nconst { basename } = require(\"node:path\");\nconst command = basename(process.argv[1]);\nconst args = process.argv.slice(2);\nappendFileSync(process.env.FIXTURE_LOG, JSON.stringify({ command, args }) + \"\\n\");\nif (command === \"git\") {\n  if (args[0] === \"rev-parse\") console.log(process.env.FIXTURE_COMMIT);\n  if (args[0] === \"status\" && process.env.FIXTURE_CASE === \"dirty\") console.log(\" M fixture\");\n} else if (command === \"codesign\" && process.env.FIXTURE_CASE === \"bad-signature\") {\n  process.exit(1);\n} else if (command === \"xcrun\" && args[0] === \"notarytool\") {\n  if (process.env.FIXTURE_CASE === \"upload-failed\") process.exit(1);\n  console.log(JSON.stringify({\n    id: \"11111111-1111-1111-1111-111111111111\",\n    status: process.env.FIXTURE_CASE === \"not-accepted\" ? \"Invalid\" : \"Accepted\"\n  }));\n}\n";
try {
  mkdirSync(join(root, "Custom"));
  mkdirSync(join(root, "Scripts"));
  mkdirSync(join(root, "bin"));
  mkdirSync(join(root, "runner", "zlaunch-validation"), { recursive: true });
  writeFileSync(join(root, "Custom", "validate-signing.sh"), script);
  writeFileSync(join(root, "Custom", "release.json"), '{"version":"0.1.9"}');
  writeFileSync(join(root, "Custom", "verify-bundle.mjs"), "");
  writeFileSync(join(root, "Scripts", "verify-signature.sh"), "#!/bin/bash\nexit 0\n");
  chmodSync(join(root, "Scripts", "verify-signature.sh"), 0o755);
  writeFileSync(join(root, "runner", "zlaunch-validation", "signing.keychain-db"), "fixture");
  for (const command of ["git", "xcodebuild", "codesign", "ditto", "xcrun", "spctl"]) {
    const path = join(root, "bin", command);
    writeFileSync(path, stub);
    chmodSync(path, 0o755);
  }
  const run = (scenario, overrides = {}) => {
    const log = join(root, "commands.jsonl");
    writeFileSync(log, "");
    const result = spawnSync("/bin/bash", [join(root, "Custom", "validate-signing.sh")], {
      cwd: root, encoding: "utf8",
      env: {
        PATH: join(root, "bin") + ":" + dirname(process.execPath) + ":/usr/bin:/bin",
        HOME: root, TMPDIR: root, GITHUB_ACTIONS: "true", RUNNER_ENVIRONMENT: "github-hosted",
        GITHUB_REPOSITORY: "zachthinks/ZLaunch", GITHUB_REF: "refs/heads/custom/main",
        GITHUB_SHA: commit, EXPECTED_COMMIT: commit, RUNNER_TEMP: join(root, "runner"),
        FIXTURE_LOG: log, FIXTURE_COMMIT: commit, FIXTURE_CASE: scenario, ...overrides
      },
    });
    const calls = readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
    return { result, calls };
  };
  const success = run("success");
  assert.equal(success.result.status, 0, success.result.stderr);
  const build = success.calls.find(call => call.command === "xcodebuild");
  assert.ok(build.args.includes("REGISTER_APP_IN_LAUNCH_SERVICES=NO"));
  assert.ok(build.args.includes("MARKETING_VERSION=0.1.9"));
  assert.ok(!build.args.some(arg => arg.startsWith("CURRENT_PROJECT_VERSION=")));
  const submit = success.calls.find(call => call.command === "xcrun" && call.args[0] === "notarytool");
  assert.equal(submit.args[submit.args.indexOf("--keychain") + 1], join(root, "runner/zlaunch-validation/signing.keychain-db"));
  const steps = success.calls.filter(call => call.command === "xcrun").map(call => call.args.slice(0, 2).join(" "));
  assert.deepEqual(steps, ["notarytool submit", "stapler staple", "stapler validate"]);
  assert.ok(success.calls.some(call => call.command === "spctl"));
  for (const scenario of ["bad-signature", "upload-failed", "not-accepted", "dirty"]) {
    const failure = run(scenario);
    assert.notEqual(failure.result.status, 0, scenario);
    assert.ok(!failure.calls.some(call => call.command === "xcrun" && call.args[0] === "stapler"), scenario);
    if (["bad-signature", "dirty"].includes(scenario)) {
      assert.ok(!failure.calls.some(call => call.command === "xcrun"), scenario);
    }
  }
  for (const overrides of [{ EXPECTED_COMMIT: "c".repeat(40) }, { RUNNER_ENVIRONMENT: "self-hosted" },
    { GITHUB_REF: "refs/heads/review" }, { GITHUB_REPOSITORY: "someone/ZLaunch" }]) {
    const failure = run("success", overrides);
    assert.notEqual(failure.result.status, 0);
    assert.ok(!failure.calls.some(call => call.command === "xcodebuild"));
  }
  console.log("Disposable signing fixtures: exact source, signature failure, notarization rejection, read-only validation and no version bump passed.");
} finally {
  rmSync(root, { recursive: true, force: true });
}
