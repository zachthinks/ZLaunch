import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import assert from "node:assert/strict";
const path = "Tinycast.xcodeproj/project.pbxproj";
const original = readFileSync(path);
function project() {
  const parsed = JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-", path], { encoding: "utf8" }));
  for (const object of Object.values(parsed.objects)) {
    if (object.isa === "PBXProject") object.targets.sort();
  }
  return parsed;
}
const before = project();
try {
  execFileSync("xcodegen", ["generate"], { stdio: "inherit" });
  assert.deepEqual(project(), before, "Generated project differs semantically; regenerate and commit it.");
} finally { writeFileSync(path, original); }
console.log("Generated project matches committed settings and sources.");
