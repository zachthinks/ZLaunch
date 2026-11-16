import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { appendFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

export function validateProfile(profile, now = new Date()) {
  const entitlement = profile.Entitlements ?? {};
  assert.equal(profile.Name, "ZLaunch Developer ID");
  assert.match(profile.UUID, /^[0-9a-f-]{36}$/i);
  assert.equal(entitlement["com.apple.application-identifier"], "FVY9AS28CU.com.zachthinks.zlaunch");
  assert.equal(entitlement["com.apple.developer.team-identifier"], "FVY9AS28CU");
  assert.ok(entitlement["keychain-access-groups"]?.some(group =>
    group === "FVY9AS28CU.*" || group === "FVY9AS28CU.com.zachthinks.zlaunch"));
  assert.ok(new Date(profile.ExpirationDate) > now);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let temporary;
  let installed;
  try {
    assert.equal(process.env.GITHUB_ACTIONS, "true");
    assert.ok(process.env.RUNNER_TEMP && process.env.GITHUB_ENV);
    const encoded = process.env.PROFILE_BASE64;
    assert.ok(encoded && /^[A-Za-z0-9+/=\s]+$/.test(encoded));
    const bytes = Buffer.from(encoded, "base64");
    temporary = mkdtempSync(join(process.env.RUNNER_TEMP, "zlaunch-profile-"));
    const source = join(temporary, "profile.provisionprofile");
    writeFileSync(source, bytes, { mode: 0o600 });
    const xml = execFileSync("security", ["cms", "-D", "-i", source], { stdio: ["ignore", "pipe", "pipe"] });
    const decode = "import sys,plistlib,json; p=plistlib.loads(sys.stdin.buffer.read()); " +
      "print(json.dumps({k:p.get(k) for k in ['Name','UUID','ExpirationDate','Entitlements']}, " +
      "default=lambda d:d.isoformat()+'Z'))";
    const json = execFileSync("python3", ["-c", decode], { input: xml, stdio: ["pipe", "pipe", "pipe"] });
    const profile = JSON.parse(json);
    validateProfile(profile);
    const directory = join(homedir(), "Library/Developer/Xcode/UserData/Provisioning Profiles");
    mkdirSync(directory, { recursive: true, mode: 0o700 });
    const destination = join(directory, profile.UUID + ".provisionprofile");
    writeFileSync(destination, bytes, { mode: 0o600, flag: "wx" });
    installed = destination;
    appendFileSync(process.env.GITHUB_ENV, "ZLAUNCH_PROFILE_PATH=" + destination + "\n");
    console.log("Installed the verified ZLaunch Developer ID profile.");
  } catch {
    if (installed) rmSync(installed, { force: true });
    console.error("Could not install the expected ZLaunch provisioning profile.");
    process.exitCode = 1;
  } finally {
    if (temporary) rmSync(temporary, { recursive: true, force: true });
  }
}
