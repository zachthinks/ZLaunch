import assert from "node:assert/strict";
import { validatePublication } from "./publication-policy.mjs";
import { validateReleaseState } from "./release-state.mjs";

export function validateHostedRelease({ metadata, commit, remoteHead, status, workflowRun,
  releases, tagRefs, promotionRunID, allowSkip = false }) {
  assert.equal(remoteHead, commit, "Main changed; check the new commit before publishing.");
  if (!status || (promotionRunID && status.target_url !==
    `https://github.com/zachthinks/ZLaunch/actions/runs/${promotionRunID}`)) {
    assert.ok(allowSkip, "No matching stable promotion for this exact commit and run.");
    return false;
  }
  validatePublication({ metadata, commit, status, workflowRun });
  const existing = releases.find(release => release.tag_name === `v${metadata.version}`);
  if (existing && allowSkip) {
    assert.equal(existing.draft, false, "Existing draft requires inspection; never overwrite it.");
    assert.equal(existing.prerelease, false);
    for (const name of [`ZLaunch-${metadata.version}.dmg`, `ZLaunch-${metadata.version}.zip`, "SHA256SUMS"]) {
      assert.ok(existing.assets?.some(asset => asset.name === name && asset.size > 0),
        "Existing release is incomplete; inspect it before retrying.");
    }
    return false;
  }
  validateReleaseState({ metadata, commit, releases, tagRefs });
  return true;
}
