import assert from "node:assert/strict";

const policy = {
  "custom-checks.yml": { verify: "macos-26" },
  "custom-release.yml": { preflight: "macos-26", release: "macos-26" },
  "custom-signing-validation.yml": { preflight: "macos-26", validate: "macos-26" },
  "custom-sync.yml": { sync: "ubuntu-latest", checks: null, promote: "ubuntu-latest" },
};

export function verifyWorkflowPolicy(workflows) {
  assert.deepEqual(Object.keys(workflows).sort(), Object.keys(policy).sort(), "Review any new custom workflow's cost policy.");
  for (const [name, expectedJobs] of Object.entries(policy)) {
    const source = workflows[name];
    const hosted = ["custom-release.yml", "custom-signing-validation.yml"].includes(name);
    if (hosted) {
      assert.match(source, /^permissions:\n  contents: read\n/m);
      const events = source.slice(source.indexOf("\non:\n"), source.indexOf("\npermissions:"));
      assert.deepEqual([...events.matchAll(/^  ([\w-]+):/gm)].map(match => match[1]), ["workflow_dispatch"]);
      assert.match(source, /group: zlaunch-release\n  cancel-in-progress: false/);
      if (name === "custom-signing-validation.yml") {
        assert.match(source, /confirm_signing_validation:[\s\S]*?default: false/);
        assert.ok(!source.includes("contents: write"));
        assert.ok(!source.includes("GH_TOKEN:"));
        assert.ok(!source.includes("Custom/publish.sh"));
        assert.ok(!source.includes("ZLAUNCH_HOSTED_RELEASE_ENABLED"));
      }
    }
    const jobs = source.slice(source.indexOf("\njobs:\n") + 7);
    const headings = [...jobs.matchAll(/^  ([\w-]+):\s*$/gm)];
    assert.deepEqual(headings.map((match) => match[1]), Object.keys(expectedJobs), `${name}: unexpected jobs`);
    for (let index = 0; index < headings.length; index++) {
      const job = headings[index][1];
      const body = jobs.slice(headings[index].index, headings[index + 1]?.index ?? jobs.length);
      const guard = name === "custom-signing-validation.yml"
        ? "github.event.repository.private == false && github.repository == 'zachthinks/ZLaunch' && github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/custom/main' && vars.ZLAUNCH_HOSTED_VALIDATION_ENABLED == 'true' && inputs.confirm_signing_validation == true" + (job === "validate" ? " && needs.preflight.result == 'success'" : "")
        : name === "custom-release.yml"
        ? "github.event.repository.private == false && github.repository == 'zachthinks/ZLaunch' && github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/custom/main' && vars.ZLAUNCH_HOSTED_RELEASE_ENABLED == 'true'" + (job === "release" ? " && needs.preflight.result == 'success'" : "")
        : job === "checks"
        ? "github.event.repository.private == false && needs.sync.outputs.candidate != ''"
        : job === "promote"
          ? "github.event.repository.private == false && needs.checks.result == 'success' && needs.sync.outputs.candidate != ''"
          : "github.event.repository.private == false";
      assert.equal(body.match(/^    if: (.+)$/m)?.[1], guard, `${name}/${job}: requires public-only execution`);
      const runner = expectedJobs[job];
      const runners = [...body.matchAll(/^\s*runs-on: (.+)$/gm)].map((match) => match[1]);
      assert.deepEqual(runners, runner ? [runner] : [], `${name}/${job}: only the reviewed standard runner is allowed`);
      if (!runner) {
        assert.match(body, /^    needs: sync$/m);
        assert.match(body, /^    uses: \.\/\.github\/workflows\/custom-checks\.yml$/m);
      }
      if (hosted) {
        const checkouts = [...body.matchAll(/uses: (.+)$/gm)].map(match => match[1]);
        assert.deepEqual(checkouts, ["actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"]);
        assert.match(body, /ref: \$\{\{ github.sha \}\}/);
        assert.match(body, /persist-credentials: false/);
        if (job === "preflight") {
          assert.ok(!body.includes("secrets."), "Preflight must not access release secrets");
          assert.ok(!body.includes("environment:"), "Preflight must not enter the signing environment");
          assert.ok(!body.includes("permissions:"), "Preflight inherits read-only permission");
        } else {
          assert.match(body, /^    needs: preflight$/m);
          assert.match(body, /^    environment: zlaunch-release$/m);
          assert.match(body, /git fetch origin custom\/main/);
          assert.match(body, /test "\$\(git rev-parse FETCH_HEAD\)" = "\$(?:GITHUB_SHA|EXPECTED_COMMIT)"/);
          assert.match(body, /test "\$\(git rev-parse HEAD\)" = "\$(?:GITHUB_SHA|EXPECTED_COMMIT)"/);
          const importAt = body.indexOf("      - name: Import signing identity");
          assert.ok(importAt > body.indexOf("git rev-parse FETCH_HEAD"));
          if (job === "release") {
            assert.match(body, /^    permissions:\n      contents: write$/m);
            assert.match(body, /node Custom\/verify-release-state.mjs/);
            assert.ok(body.indexOf("node Custom/verify-release-state.mjs") < importAt);
            assert.match(body, /exit "\$CLEANUP_STATUS"/);
            assert.match(body, /NOTARY_KEYCHAIN: \$\{\{ runner.temp \}\}\/zlaunch.keychain-db/);
            assert.match(body, /--keychain "\$RUNNER_TEMP\/zlaunch.keychain-db"/);
            assert.match(body, /name: Remove temporary signing material\n        if: always\(\)[\s\S]*security delete-keychain "\$RUNNER_TEMP\/zlaunch.keychain-db"/);
          } else {
            assert.ok(!body.includes("permissions:"));
            assert.match(body, /--keychain "\$RUNNER_TEMP\/zlaunch-validation\/signing.keychain-db"/);
            assert.match(body, /run: \.\/Custom\/validate-signing.sh/);
            assert.match(body, /name: Remove temporary signing material and build\n        if: always\(\)[\s\S]*security delete-keychain "\$VALIDATION_DIR\/signing.keychain-db"/);
            assert.match(body, /rm -rf "\$VALIDATION_DIR" \|\| CLEANUP_STATUS=1/);
            assert.match(body, /exit "\$CLEANUP_STATUS"/);
          }
        }
        if (name === "custom-signing-validation.yml") {
          assert.match(body, /git fetch origin custom\/main/);
          assert.match(body, /EXPECTED_COMMIT: \$\{\{ inputs.expected_commit \}\}/);
          assert.match(body, /test "\$EXPECTED_COMMIT" = "\$GITHUB_SHA"/);
          assert.match(body, /test "\$\(git rev-parse FETCH_HEAD\)" = "\$EXPECTED_COMMIT"/);
        }
      }
      if (job === "promote") {
        assert.match(body, /^    needs: \[sync, checks\]$/m);
        assert.match(body, /ref: \$\{\{ needs.sync.outputs.candidate \}\}/);
        assert.match(body, /CHECKED_COMMIT: \$\{\{ needs.sync.outputs.candidate \}\}/);
        assert.match(body, /SYNC_BASE: \$\{\{ needs.sync.outputs.base \}\}/);
        assert.match(body, /run: node Custom\/promote\.mjs/);
      }
    }
    const actions = [...source.matchAll(/^\s*(?:- )?uses: (.+)$/gm)].map((match) => match[1]);
    for (const action of actions) {
      assert.ok(["actions/checkout@v7", "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1", "./.github/workflows/custom-checks.yml"].includes(action),
        `${name}: unreviewed action; artifact uploads and caches are not allowed`);
    }
  }
}
