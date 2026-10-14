import assert from "node:assert/strict";

const versionParts = (version) => {
  assert.match(version, /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/);
  return version.split(".").map(BigInt);
};

export function validateReleaseState({ metadata, commit, releases, tagRefs }) {
  assert.equal(metadata.repository, "zachthinks/ZLaunch");
  assert.equal(metadata.team, "FVY9AS28CU");
  assert.equal(metadata.upstream_prerelease, false);
  assert.match(metadata.upstream_tag, /^v\d+\.\d+\.\d+$/);
  assert.match(metadata.upstream_commit, /^[a-f0-9]{40}$/);
  assert.match(commit, /^[a-f0-9]{40}$/);
  const next = versionParts(metadata.version);
  assert.ok(Array.isArray(releases), "Invalid release response.");
  for (const release of releases) {
    assert.equal(typeof release.tag_name, "string");
    assert.equal(typeof release.draft, "boolean");
    assert.equal(typeof release.prerelease, "boolean");
    assert.notEqual(release.tag_name, "v" + metadata.version, "Version already exists, including drafts.");
    if (!release.draft && !release.prerelease) {
      assert.ok(release.tag_name.startsWith("v"), "Unrecognized stable release tag.");
      const previous = versionParts(release.tag_name.slice(1));
      const differing = next.findIndex((part, index) => part !== previous[index]);
      assert.ok(differing >= 0 && next[differing] > previous[differing], "Release version must increase.");
    }
  }
  const tag = "refs/tags/v" + metadata.version;
  const refs = new Map();
  for (const line of tagRefs.trim().split("\n").filter(Boolean)) {
    const [sha, ref, extra] = line.split(/\s+/);
    assert.equal(extra, undefined);
    assert.match(sha, /^[a-f0-9]{40}$/);
    assert.ok(ref === tag || ref === tag + "^{}", "Unexpected remote tag.");
    assert.ok(!refs.has(ref), "Duplicate tag ref.");
    refs.set(ref, sha);
  }
  const target = refs.get(tag + "^{}") ?? refs.get(tag);
  if (target) assert.equal(target, commit, "Remote tag targets a different commit.");
}
