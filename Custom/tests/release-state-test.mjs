import assert from "node:assert/strict";
import { validateReleaseState } from "../release-state.mjs";

const valid = {
  metadata: { repository: "zachthinks/ZLaunch", team: "FVY9AS28CU", version: "0.1.10",
    upstream_tag: "v0.11.19", upstream_commit: "a".repeat(40), upstream_prerelease: false },
  commit: "b".repeat(40),
  releases: [{ tag_name: "v0.1.9", draft: false, prerelease: false }],
  tagRefs: "",
};
validateReleaseState(valid);
const reject = mutate => {
  const candidate = structuredClone(valid);
  mutate(candidate);
  assert.throws(() => validateReleaseState(candidate));
};
reject(x => x.metadata.version = "0.1.9");
reject(x => x.metadata.version = "0.1.8");
reject(x => x.metadata.version = "0.01.10");
reject(x => x.metadata.team = "OTHER");
reject(x => x.metadata.repository = "other/repo");
reject(x => x.metadata.upstream_prerelease = true);
reject(x => x.commit = "main");
reject(x => x.releases.push({ tag_name: "v0.1.10", draft: true, prerelease: false }));
reject(x => x.releases.push({ tag_name: "v0.1.10", draft: false, prerelease: true }));
reject(x => x.releases.push({ tag_name: "v1.0.0", draft: false, prerelease: false }));
reject(x => x.releases[0].tag_name = "unrecognized");
reject(x => delete x.releases[0].draft);
reject(x => x.tagRefs = "c".repeat(40) + "\trefs/tags/v0.1.10");
validateReleaseState({ ...valid, tagRefs: valid.commit + "\trefs/tags/v0.1.10" });
validateReleaseState({ ...valid, tagRefs: "c".repeat(40) + "\trefs/tags/v0.1.10\n" +
  valid.commit + "\trefs/tags/v0.1.10^{}" });
reject(x => x.tagRefs = valid.commit + "\trefs/tags/v0.1.10\n" + "c".repeat(40) + "\trefs/tags/v0.1.10^{}");
validateReleaseState({ ...valid, metadata: { ...valid.metadata, version: "0.2.0" } });
validateReleaseState({ ...valid, releases: [...valid.releases,
  { tag_name: "v0.2.0-beta.1", draft: false, prerelease: true }] });
console.log("Release state rejects reused/draft versions, downgrade, invalid identity and wrong tag targets.");
