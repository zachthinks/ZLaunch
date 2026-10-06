import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const gh = (...args) => execFileSync("gh", args, { encoding: "utf8" }).trim();
const startingBranch = git("branch", "--show-current");
if (startingBranch !== "custom/main") throw new Error("Start sync from custom/main.");
const startingSHA = git("rev-parse", "HEAD");
const meta = JSON.parse(readFileSync("Custom/release.json", "utf8"));
if (git("status", "--porcelain")) throw new Error("Commit or stash changes first; sync never overwrites local work.");
const latest = JSON.parse(gh("api", "repos/abue-ammar/tinycast/releases/latest"));
if (!/^v\d+\.\d+\.\d+$/.test(latest.tag_name) || latest.draft || latest.prerelease) throw new Error("Not a stable upstream release.");
if (meta.upstream_tag === latest.tag_name) { console.log("Already current."); process.exit(0); }
const tag = latest.tag_name;
git("fetch", "upstream", `refs/tags/${tag}:refs/remotes/upstream/releases/${tag}`);
const sha = git("rev-parse", `refs/remotes/upstream/releases/${tag}^{commit}`);
if (!/^([a-f0-9]{40})$/.test(sha)) throw new Error("Invalid upstream commit.");
if (spawnSync("git", ["merge-base", "--is-ancestor", sha, "HEAD"]).status === 0) {
 console.log(`Already contains stable upstream ${tag}; keep the newer recorded base.`); process.exit(0);
}
const branch = `sync/upstream-${tag.slice(1)}`;
if (git("ls-remote", "--heads", "origin", branch)) {
 git("fetch", "origin", branch);
 const remoteSHA = git("rev-parse", "FETCH_HEAD");
 try {
  const localSHA = git("rev-parse", "--verify", branch);
  if (localSHA !== remoteSHA) throw new Error("Local candidate has different commits; review it first.");
  git("switch", branch);
 } catch (error) {
  if (!error.status) throw error;
  git("switch", "-c", branch, remoteSHA);
 }
 console.log(`Resume ${branch}`); process.exit(0);
}
try { git("show-ref", "--verify", `refs/heads/${branch}`); throw new Error("Local candidate exists; review it before retrying."); }
catch (error) { if (!error.status) throw error; }
git("switch", "-c", branch);
const merge = spawnSync("git", ["merge", "--no-commit", "--no-ff", sha], { encoding: "utf8" });
if (merge.status !== 0) {
 const conflicts = git("diff", "--name-only", "--diff-filter=U");
 try { mkdirSync("build", { recursive: true }); writeFileSync("build/sync-conflicts.txt", `Upstream ${tag} (${sha})\n${conflicts}\n${merge.stdout}\n${merge.stderr}`); }
 finally {
  git("merge", "--abort");
  git("switch", startingBranch);
  if (git("rev-parse", branch) === startingSHA) git("branch", "-D", branch);
 }
 throw new Error(`Merge stopped. Your custom branch is intact. Conflicts: ${conflicts}`);
}
const next = JSON.parse(readFileSync("Custom/release.json", "utf8"));
next.upstream_tag = tag; next.upstream_commit = sha; next.upstream_prerelease = false;
const parts = next.version.split(".").map(Number); parts[2]++; next.version = parts.join(".");
writeFileSync("Custom/release.json", JSON.stringify(next, null, 2) + "\n");
git("add", "Custom/release.json");
git("commit", "-m", `Sync upstream ${tag} into ZLaunch`);
console.log(branch);
