import assert from "node:assert/strict";
import { githubReleaseAPI } from "../github-release-api.mjs";

const token = "fixture-token-never-log";
const response = (status, body, headers = {}) => new Response(JSON.stringify(body), { status, headers });
async function scenario(responses, path = "releases?per_page=100") {
  const requests = [], waits = [], warnings = [];
  const api = githubReleaseAPI({ token, now: () => 0,
    fetcher: async (url, options) => {
      requests.push({ url, options });
      const next = responses.shift();
      if (next instanceof Error) throw next;
      assert.ok(next, "Unexpected extra request");
      return next;
    }, wait: async ms => waits.push(ms), warn: line => warnings.push(line) });
  let result, error;
  try { result = await api(path); } catch (caught) { error = caught; }
  for (const request of requests) {
    assert.equal(request.options.headers.Authorization, `Bearer ${token}`);
    assert.equal(new URL(request.url).origin, "https://api.github.com");
    assert.equal(request.options.redirect, "error");
  }
  assert.ok(!`${error ?? ""}${warnings.join()}`.includes(token), "Diagnostics must not leak a token");
  return { requests, waits, warnings, result, error };
}
let result = await scenario([response(200, Array(100).fill({ tag_name: "v0.1.1" })), response(200, [])]);
assert.equal(result.result.length, 2);
assert.match(result.requests[1].url, /page=2$/);
result = await scenario([response(503, {}), response(200, [])]);
assert.deepEqual(result.waits, [1000]);
result = await scenario([new Error(token), new Error(token), new Error(token)]);
assert.equal(result.requests.length, 3);
assert.deepEqual(result.waits, [1000, 2000]);
assert.match(result.error.message, /transport failure, attempt 3\/3/);
result = await scenario([response(429, {}, { "retry-after": "2" }), response(200, [])]);
assert.deepEqual(result.waits, [2000]);
result = await scenario([response(403, { message: "API rate limit exceeded" }, {
  "x-ratelimit-remaining": "0", "x-ratelimit-reset": "5", "x-github-request-id": "ABC:123",
}), response(200, [])]);
assert.deepEqual(result.waits, [5000]);
assert.match(result.warnings[0], /HTTP 403, rate limit; remaining=0, reset=5/);
result = await scenario([response(403, { message: "secondary rate limit" }, { "retry-after": "60" })]);
assert.equal(result.requests.length, 1);
assert.match(result.error.message, /Publication stopped/);
for (const status of [401, 403, 404]) {
  result = await scenario([response(status, { message: token })]);
  assert.equal(result.requests.length, 1);
  assert.match(result.error.message, new RegExp(`HTTP ${status}`));
}
result = await scenario([response(500, {}), response(502, {}), response(504, {})]);
assert.equal(result.requests.length, 3);
assert.match(result.error.message, /attempt 3\/3/);
result = await scenario([new Response("not JSON", { status: 200 })]);
assert.match(result.error.message, /invalid JSON/);
console.log("GitHub release API: authentication, pagination, bounded retries, rate/permission diagnostics and token redaction passed.");
for (const path of [
  `actions/workflows/custom-checks.yml/runs?head_sha=${"a".repeat(40)}&per_page=100`,
  "actions/runs/123/attempts/2/jobs?per_page=100",
]) {
  result = await scenario([response(200, { workflow_runs: [], jobs: [], total_count: 0 })], path);
  assert.equal(result.error, undefined);
  assert.equal(result.requests.length, 1);
}
for (const path of ["actions/workflows/other.yml/runs", "actions/runs/123/attempts/2/secrets", "../secrets"]) {
  result = await scenario([], path);
  assert.ok(result.error);
  assert.equal(result.requests.length, 0);
}
console.log("Only the reviewed check-run and attempt-job metadata endpoints are accepted.");
