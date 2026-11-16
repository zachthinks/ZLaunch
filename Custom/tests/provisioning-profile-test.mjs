import assert from "node:assert/strict";
import { validateProfile } from "../install-provisioning-profile.mjs";
const profile = {
  Name: "ZLaunch Developer ID", UUID: "11111111-1111-1111-1111-111111111111",
  ExpirationDate: "2030-01-01T00:00:00Z",
  Entitlements: {
    "com.apple.application-identifier": "FVY9AS28CU.com.zachthinks.zlaunch",
    "com.apple.developer.team-identifier": "FVY9AS28CU",
    "keychain-access-groups": ["FVY9AS28CU.*"],
  },
};
const now = new Date("2026-01-01T00:00:00Z");
validateProfile(profile, now);
for (const mutate of [
  p => { p.ExpirationDate = "2025-01-01T00:00:00Z"; },
  p => { p.UUID = "../../wrong"; },
  p => { p.Name = "Wrong app"; },
  p => { p.Entitlements["com.apple.application-identifier"] += ".dev"; },
  p => { p.Entitlements["com.apple.developer.team-identifier"] = "OTHER"; },
  p => { p.Entitlements["keychain-access-groups"] = ["OTHER.*"]; },
]) {
  const changed = structuredClone(profile);
  mutate(changed);
  assert.throws(() => validateProfile(changed, now));
}
console.log("Provisioning rejects expired profiles, wrong app/team/groups and unsafe filenames.");
