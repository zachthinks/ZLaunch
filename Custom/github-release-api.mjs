import assert from "node:assert/strict";

const repository = "zachthinks/ZLaunch";
const attempts = 3;
const maxWait = 10_000;
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

export function githubReleaseAPI({ token = process.env.GH_TOKEN, fetcher = fetch,
  wait = sleep, warn = console.warn, now = Date.now } = {}) {
  const auth = token ? "workflow token" : "public unauthenticated";
  async function request(path) {
    assert.match(path, /^(releases|commits\/[a-f0-9]{40}\/statuses|actions\/runs\/\d+(?:\/attempts\/\d+\/jobs)?|actions\/workflows\/custom-checks\.yml\/runs)(\?|$)/);
    for (let attempt = 1; attempt <= attempts; attempt++) {
      let response;
      try {
        response = await fetcher(`https://api.github.com/repos/${repository}/${path}`, {
          headers: { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
            ...(token ? { Authorization: `Bearer ${token}` } : {}) },
          redirect: "error", signal: AbortSignal.timeout(20_000),
        });
      } catch {
        const diagnostic = `GitHub GET ${path} (${auth}): transport failure, attempt ${attempt}/${attempts}.`;
        if (attempt === attempts) throw new Error(diagnostic);
        warn(diagnostic);
        await wait(attempt * 1000);
        continue;
      }
      let data;
      try { data = await response.json(); } catch { /* HTTP diagnostics do not require a JSON body. */ }
      if (response.ok) {
        assert.ok(data && typeof data === "object", `GitHub GET ${path}: invalid JSON response.`);
        return data;
      }
      const remaining = response.headers.get("x-ratelimit-remaining");
      const rateLimited = response.status === 429 || (response.status === 403 &&
        (remaining === "0" || /rate limit|secondary rate|abuse/i.test(data?.message ?? "")));
      const reason = rateLimited ? "rate limit" : [401, 403].includes(response.status)
        ? "authentication/permission denied; existing token permissions were not expanded" : "API error";
      const safe = value => (token ? (value ?? "unknown").replaceAll(token, "REDACTED") : (value ?? "unknown"))
        .replace(/[^a-zA-Z0-9:._-]/g, "").slice(0, 80);
      const diagnostic = `GitHub GET ${path} (${auth}): HTTP ${response.status}, ${reason}; ` +
        `remaining=${safe(remaining)}, reset=${safe(response.headers.get("x-ratelimit-reset"))}, ` +
        `retry-after=${safe(response.headers.get("retry-after"))}, ` +
        `request-id=${safe(response.headers.get("x-github-request-id"))}; attempt ${attempt}/${attempts}.`;
      const retryable = rateLimited || [500, 502, 503, 504].includes(response.status);
      const retryAfter = response.headers.get("retry-after");
      const reset = response.headers.get("x-ratelimit-reset");
      const delay = retryAfter !== null ? (/^\d+$/.test(retryAfter) ? Number(retryAfter) * 1000
        : Date.parse(retryAfter) - now()) : rateLimited && remaining === "0" && reset
        ? Number(reset) * 1000 - now() : rateLimited ? 60_000 : attempt * 1000;
      if (!retryable || attempt === attempts || !Number.isFinite(delay) || delay > maxWait) {
        throw new Error(`${diagnostic} Publication stopped; inspect this response before retrying.`);
      }
      warn(`${diagnostic} Retrying in ${Math.max(0, delay)}ms.`);
      await wait(Math.max(0, delay));
    }
  }
  return async path => {
    const pages = [];
    for (let page = 1; page <= 100; page++) {
      const separator = path.includes("?") ? "&" : "?";
      const result = await request(`${path}${separator}page=${page}`);
      pages.push(result);
      if (!Array.isArray(result) || result.length < 100) return pages;
    }
    throw new Error(`GitHub GET ${path}: pagination limit exceeded; publication stopped.`);
  };
}
