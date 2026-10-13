import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { validateReleaseState } from "./release-state.mjs";

const run = (command, args) => execFileSync(command, args, { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 }).trim();
const metadata = JSON.parse(readFileSync("Custom/release.json", "utf8"));
const pages = JSON.parse(run("gh", ["api", "--paginate", "--slurp", "repos/zachthinks/ZLaunch/releases"]));
if (!Array.isArray(pages) || !pages.every(Array.isArray)) throw new Error("Invalid paginated release response.");
const tag = "refs/tags/v" + metadata.version;
validateReleaseState({
  metadata,
  commit: run("git", ["rev-parse", "HEAD"]),
  releases: pages.flat(),
  tagRefs: run("git", ["ls-remote", "origin", tag, tag + "^{}"]),
});
console.log("Release identity, monotonic version, draft absence and remote tag target verified.");
