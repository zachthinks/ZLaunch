import assert from "node:assert/strict";

const policy = {
  "custom-checks.yml": { verify: "macos-26" },
  "custom-release.yml": { release: "macos-26" },
  "custom-sync.yml": { sync: "ubuntu-latest", checks: null },
};

export function verifyWorkflowPolicy(workflows) {
  assert.deepEqual(Object.keys(workflows).sort(), Object.keys(policy).sort(), "Review any new custom workflow's cost policy.");
  for (const [name, expectedJobs] of Object.entries(policy)) {
    const source = workflows[name];
    const jobs = source.slice(source.indexOf("\njobs:\n") + 7);
    const headings = [...jobs.matchAll(/^  ([\w-]+):\s*$/gm)];
    assert.deepEqual(headings.map((match) => match[1]), Object.keys(expectedJobs), `${name}: unexpected jobs`);
    for (let index = 0; index < headings.length; index++) {
      const job = headings[index][1];
      const body = jobs.slice(headings[index].index, headings[index + 1]?.index ?? jobs.length);
      const guard = job === "checks"
        ? "github.event.repository.private == false && needs.sync.outputs.candidate != ''"
        : "github.event.repository.private == false";
      assert.equal(body.match(/^    if: (.+)$/m)?.[1], guard, `${name}/${job}: requires public-only execution`);
      const runner = expectedJobs[job];
      const runners = [...body.matchAll(/^\s*runs-on: (.+)$/gm)].map((match) => match[1]);
      assert.deepEqual(runners, runner ? [runner] : [], `${name}/${job}: only the reviewed standard runner is allowed`);
      if (!runner) {
        assert.match(body, /^    needs: sync$/m);
        assert.match(body, /^    uses: \.\/\.github\/workflows\/custom-checks\.yml$/m);
      }
    }
    const actions = [...source.matchAll(/^\s*(?:- )?uses: (.+)$/gm)].map((match) => match[1]);
    for (const action of actions) {
      assert.ok(["actions/checkout@v7", "./.github/workflows/custom-checks.yml"].includes(action),
        `${name}: unreviewed action; artifact uploads and caches are not allowed`);
    }
  }
}
