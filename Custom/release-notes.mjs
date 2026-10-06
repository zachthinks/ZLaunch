import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const upstreamRepository = "abue-ammar/tinycast";
const installMarker = "<!-- tinycast:install -->";
const firstReleaseChanges = [
  "ZLaunch has its own app identity, settings, extension storage, permissions and login item, so Tinycast can remain installed.",
  "The extension Store adds Developer Tools, Productivity, Notes and AI search starting points.",
  "Updates use ZLaunch releases and verify the custom app identity and signing team before replacement.",
  "Installed AI tool consent is handled one choice at a time; turning extensions off waits for their sessions to stop.",
  "Extension cleanup stays unavailable while extensions are off, protecting imported preferences."
];

export function upstreamSummary(body) {
  return body.split(installMarker, 1)[0].replaceAll("\r\n", "\n").trim()
    .replace(/(^|[^\w/\[])#(\d+)\b/g, (_, prefix, number) =>
      `${prefix}[#${number}](https://github.com/${upstreamRepository}/issues/${number})`);
}

export function previousReleaseDetails(release) {
  if (!release) return null;
  const marker = release.body.match(/<!-- zlaunch:base (\{[^\n]*\}) -->/);
  let base = {};
  if (marker) base = JSON.parse(marker[1]);
  const upstreamTag = base.upstream_tag ?? release.body.match(/based on Tinycast (v\d+\.\d+\.\d+(?:-beta\.\d+)?)/i)?.[1];
  const sourceCommit = base.source_commit ?? release.body.match(/github\.com\/[^/]+\/[^/]+\/tree\/([a-f0-9]{40})\b/)?.[1];
  return { tag: release.tagName, upstreamTag, sourceCommit };
}

export function renderReleaseNotes({ metadata, commit, upstream, previous = null, changes = [] }) {
  if (!/^\d+\.\d+\.\d+$/.test(metadata.version) || !/^v\d+\.\d+\.\d+(?:-beta\.\d+)?$/.test(metadata.upstream_tag)
      || !/^[a-f0-9]{40}$/.test(metadata.upstream_commit) || !/^[a-f0-9]{40}$/.test(commit)
      || !/^[\w.-]+\/[\w.-]+$/.test(metadata.repository)) throw new Error("Invalid release provenance.");
  const upstreamURL = `https://github.com/${upstreamRepository}/releases/tag/${metadata.upstream_tag}`;
  const prerelease = metadata.upstream_prerelease === true;
  if (prerelease !== /-beta\.\d+$/.test(metadata.upstream_tag)
      || upstream.tagName !== metadata.upstream_tag || upstream.url !== upstreamURL || upstream.isDraft
      || upstream.isPrerelease !== prerelease)
    throw new Error("The official release does not match the explicitly selected upstream channel.");
  const summary = upstreamSummary(upstream.body);
  if (!summary) throw new Error("The official release has no usable release notes.");
  const sameBase = previous?.upstreamTag === metadata.upstream_tag;
  const sections = [
    `# ZLaunch ${metadata.version}`,
    `Based on Tinycast ${metadata.upstream_tag}${prerelease ? " (upstream beta)" : ""}. [Official upstream release](${upstreamURL}).`,
    "## ZLaunch changes",
    !previous ? firstReleaseChanges.map(x => `- ${x}`).join("\n")
      : changes.length ? changes.map(x => `- ${x}`).join("\n")
      : "See the exact source changes linked below for this custom release.",
    "## Included upstream release notes",
    sameBase
      ? `The Tinycast base is unchanged from ZLaunch ${previous.tag.replace(/^v/, "")}. The inherited notes below describe that base; they are not new fixes introduced by this ZLaunch update.`
      : previous?.upstreamTag ? `This release updates the Tinycast base to ${metadata.upstream_tag}. The following notes come from the official upstream release.`
      : previous ? "The following inherited notes describe the included Tinycast base. The previous release did not record enough provenance to identify an upstream-base change."
      : "The following notes come from the official Tinycast release included in this first ZLaunch release.",
    summary,
    "## Matching source",
    `[ZLaunch source at ${commit}](https://github.com/${metadata.repository}/tree/${commit}).\n\n[Tinycast source at ${metadata.upstream_commit}](https://github.com/${upstreamRepository}/tree/${metadata.upstream_commit}).`
  ];
  if (previous?.sourceCommit && /^[a-f0-9]{40}$/.test(previous.sourceCommit))
    sections.push(`[ZLaunch changes since ${previous.tag}](https://github.com/${metadata.repository}/compare/${previous.sourceCommit}...${commit}).`);
  return sections.join("\n\n") + "\n";
}

function command(executable, args) {
  return execFileSync(executable, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

function main(output) {
  if (!output) throw new Error("Usage: node Custom/release-notes.mjs <output.md>");
  const metadata = JSON.parse(readFileSync("Custom/release.json", "utf8"));
  const commit = command("git", ["rev-parse", "HEAD"]);
  const upstream = JSON.parse(command("gh", ["release", "view", metadata.upstream_tag, "--repo", upstreamRepository,
    "--json", "body,name,url,tagName,isDraft,isPrerelease"]));
  const upstreamCommit = command("gh", ["api", `repos/${upstreamRepository}/commits/${metadata.upstream_tag}`, "--jq", ".sha"]);
  if (upstreamCommit !== metadata.upstream_commit) throw new Error("Upstream tag does not match the pinned source commit.");
  const releases = JSON.parse(command("gh", ["release", "list", "--repo", metadata.repository,
    "--limit", "100", "--json", "tagName,isDraft,isPrerelease"]));
  const prior = releases.find(x => /^v\d+\.\d+\.\d+$/.test(x.tagName) && !x.isDraft && !x.isPrerelease && x.tagName !== `v${metadata.version}`);
  const previous = previousReleaseDetails(prior ? JSON.parse(command("gh", ["release", "view", prior.tagName,
    "--repo", metadata.repository, "--json", "body,tagName"])) : null);
  let changes = [];
  if (previous?.sourceCommit && /^[a-f0-9]{40}$/.test(previous.sourceCommit)) {
    try { changes = command("git", ["log", "--first-parent", "--format=%s", `${previous.sourceCommit}..${commit}`]).split("\n").filter(Boolean); }
    catch { /* The comparison link remains usable when an old commit is absent locally. */ }
  }
  const notes = renderReleaseNotes({ metadata, commit, upstream, previous, changes });
  mkdirSync(dirname(resolve(output)), { recursive: true });
  writeFileSync(output, notes);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv[2]); }
  catch (error) { console.error(`Release notes generation failed: ${error.message}`); process.exitCode = 1; }
}
