import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const [app, channel] = process.argv.slice(2);
assert.ok(app && ["Debug", "Release"].includes(channel), "Pass an app path and Debug or Release.");
const plist = (path) => JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-", path], { encoding: "utf8" }));
const name = channel === "Debug" ? "ZLaunch Dev" : "ZLaunch";
const id = channel === "Debug" ? "com.zachthinks.zlaunch.dev" : "com.zachthinks.zlaunch";
const info = plist(join(app, "Contents/Info.plist"));
assert.equal(info.CFBundleIdentifier, id);
assert.equal(info.CFBundleExecutable, name);
assert.deepEqual(info.CFBundleURLTypes.flatMap((type) => type.CFBundleURLSchemes),
  [channel === "Debug" ? "zlaunch-dev" : "zlaunch"]);
assert.match(info.NSMicrophoneUsageDescription, /ZLaunch/);
const helperName = `${name} Dictation`;
const helper = join(app, `Contents/Helpers/${helperName}.app`);
const helperInfo = plist(join(helper, "Contents/Info.plist"));
assert.equal(helperInfo.CFBundleIdentifier, `${id}.dictation`);
assert.equal(helperInfo.CFBundleExecutable, helperName);
assert.equal(helperInfo.CFBundleDisplayName, helperName);
for (const executable of [join(app, `Contents/MacOS/${name}`),
  join(app, "Contents/Helpers/ClipboardTextHelper"), join(helper, `Contents/MacOS/${helperName}`)]) {
  assert.ok(existsSync(executable), `Missing embedded executable: ${executable}`);
  assert.equal(execFileSync("lipo", ["-archs", executable], { encoding: "utf8" }).trim(), "arm64");
}
console.log(`${channel} built app, helper identity, executable names, architecture, and URL isolation verified.`);
