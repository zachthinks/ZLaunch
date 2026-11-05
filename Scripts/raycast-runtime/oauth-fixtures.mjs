import { pathToFileURL } from "node:url";
import { bootConfig, createHarness } from "./test.mjs";

const providerName = "Café & Bar #2 + 東京";
const opaqueState = /^[\w-]{22}$/;

// Stands in for the hosted page: take the scheme from the envelope and echo `state` back as sent.
function relay(state) {
  const { scheme } = JSON.parse(Buffer.from(state, "base64url").toString());
  if (scheme !== "zlaunch-dev") throw new Error("Callback escaped the configured channel");
  return { authorizationCode: "relayed", state };
}

export async function runOAuthFixtures(check) {
  let respond;
  const harness = createHarness({
    stubs: { "oauth.authorize": ([url]) => respond(new URL(url).searchParams.get("state")) },
  });
  harness.boot(bootConfig());
  harness.start("oauth", `
    const { OAuth } = require("@raycast/api");
    module.exports.default = () => {
      globalThis.prepare = async (method, extraParameters) => {
        globalThis.client = new OAuth.PKCEClient({ redirectMethod: OAuth.RedirectMethod[method], providerName: ${JSON.stringify(providerName)} });
        globalThis.request = await client.authorizationRequest({ endpoint: "https://auth.example.test/authorize", clientId: "fixture", scope: "repo", extraParameters });
        return { state: request.state, verifier: request.codeVerifier };
      };
      globalThis.signIn = (target) => client.authorize(target ?? request)
        .then(({ authorizationCode }) => authorizationCode, (error) => error.message);
    };`, "/oauth.js", "/", "no-view", {});
  await new Promise((resolve) => setTimeout(resolve, 20));
  const signIn = () => harness.call("signIn()");
  const signInWithURL = () => harness.call("signIn({ url: request.toURL() })");
  const bothSignIns = async () => [await signIn(), await signInWithURL()];
  const rejected = (results) => results.every((result) => result.includes("mismatched state"));

  try {
    const web = await harness.call('prepare("Web")');
    const envelope = JSON.parse(Buffer.from(web.state, "base64url").toString());
    check("web state is a base64url envelope", /^[\w-]+$/.test(web.state) && envelope.scheme === "zlaunch-dev"
      && opaqueState.test(envelope.token), JSON.stringify(envelope));
    check("the envelope keeps the provider name intact", envelope.providerName === providerName, envelope.providerName);
    respond = relay;
    const relayed = await bothSignIns();
    check("a relayed web sign-in returns its code", relayed.every((code) => code === "relayed"), JSON.stringify(relayed));

    const next = await harness.call('prepare("Web")');
    check("each request draws a fresh state and verifier", next.state !== web.state && next.verifier !== web.verifier);
    for (const [label, returnedState] of [
      ["a missing", undefined],
      ["an empty", ""],
      ["a mismatched", "wrong"],
    ]) {
      respond = () => ({ authorizationCode: "relayed", state: returnedState });
      const results = await bothSignIns();
      check(`${label} state is rejected`, rejected(results), JSON.stringify(results));
    }
    respond = () => relay(web.state);
    const stale = await bothSignIns();
    check("a stale request's state is rejected", rejected(stale), JSON.stringify(stale));
    respond = (state) => ({ state });
    const codeless = await signIn();
    check("a redirect without a code is rejected", codeless.includes("no authorization code"), codeless);

    for (const [method, target] of [
      ["App", "zlaunch-dev://oauth"],
      ["AppURI", "zlaunch-dev://oauth"],
      ["ClientIdMetadataDocument", "zlaunch-dev://oauth"],
    ]) {
      const { state } = await harness.call(`prepare("${method}", { redirect_uri: "${target}" })`);
      respond = (sent) => ({ authorizationCode: "direct", state: sent });
      const returned = await signIn();
      respond = () => ({ authorizationCode: "direct" });
      const missing = await signIn();
      check(`${method} sends isolated state and requires it back`,
        JSON.parse(Buffer.from(state, "base64url").toString()).scheme === "zlaunch-dev" && returned === "direct" && rejected([missing]), JSON.stringify([state, returned, missing]));
    }

    for (const target of ["raycast://oauth", "tinycast://oauth", "zlaunch://oauth"]) {
      const failure = await harness.call(`prepare("App", { redirect_uri: ${JSON.stringify(target)} }).then(() => "accepted", (error) => error.message)`);
      check("rejects a callback outside the configured channel", failure.includes("OAuth callback must use zlaunch-dev"), failure);
    }

    await harness.call('prepare("App", { state: "custom-state", redirect_uri: "zlaunch-dev://oauth" })');
    respond = (sent) => ({ authorizationCode: "custom", state: sent });
    const overridden = await bothSignIns();
    check("an extra state parameter is the one checked", overridden.every((code) => code === "custom"), JSON.stringify(overridden));
    respond = () => ({ authorizationCode: "stateless" });
    const stateless = await harness.call('signIn({ url: "https://auth.example.test/authorize" })');
    check("a custom URL without state is not checked", stateless === "stateless", stateless);
  } finally {
    harness.stop("oauth");
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  let failures = 0;
  await runOAuthFixtures((label, condition, detail) => {
    console.log(`${condition ? "✓" : "✗"} ${label}${condition ? "" : ` — ${detail}`}`);
    if (!condition) failures++;
  });
  process.exitCode = failures ? 1 : 0;
}
