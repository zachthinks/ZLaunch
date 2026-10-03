import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { verifyWorkflowPolicy } from "./workflow-policy.mjs";
const text = (p) => readFileSync(p, "utf8");
const metadata = JSON.parse(text("Custom/release.json"));
assert.match(metadata.version, /^\d+\.\d+\.\d+$/);
assert.equal(metadata.repository, "zachthinks/ZLaunch");
const project = text("project.yml");
assert.match(project, /PRODUCT_BUNDLE_IDENTIFIER: com\.zachthinks\.zlaunch\n/);
assert.match(project, /PRODUCT_BUNDLE_IDENTIFIER: com\.zachthinks\.zlaunch\.dev/);
assert.match(project, /ZLAUNCH_URL_SCHEME: zlaunch-dev/);
const plist = text("Tinycast/Info.plist");
const schemes = plist.split("<key>CFBundleURLSchemes</key>")[1].split("</array>")[0];
assert.equal((schemes.match(/<string>/g) || []).length, 1);
assert.match(schemes, /\$\(ZLAUNCH_URL_SCHEME\)/);
assert.match(text("Tinycast/Features/Updates/Model/ReleaseFeed.swift"), /"zachthinks\/ZLaunch"/);
const signature = text("Tinycast/Features/Updates/Service/BundleSignature.swift");
assert.match(signature, /FVY9AS28CU/);
assert.ok(!signature.includes("SPBUD83MLU"));
assert.ok(!signature.includes("return running == candidate"));
assert.match(text("Tinycast/Features/Extensions/Service/ExtensionOAuthKeychain.swift"), /Bundle\.main\.bundleIdentifier/);
console.log("Custom identity, update feed, trust, and scheme isolation verified.");

verifyWorkflowPolicy(Object.fromEntries(readdirSync(".github/workflows")
  .filter((name) => /^custom.*\.ya?ml$/.test(name))
  .map((name) => [name, text(`.github/workflows/${name}`)])));
console.log("Custom workflows use public-only standard runners without artifacts or caches.");
