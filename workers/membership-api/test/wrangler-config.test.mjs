import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const configUrl = new URL("../wrangler.toml", import.meta.url);

test("production deploy requires every Worker secret", async () => {
  const config = await readFile(configUrl, "utf8");
  const secretsBlock = config.match(/\[secrets\]([\s\S]*?)(?=\n\[|$)/)?.[1] ?? "";
  const requiredBlock = secretsBlock.match(/required\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  const requiredSecrets = new Set(
    [...requiredBlock.matchAll(/"([A-Z0-9_]+)"/g)].map((match) => match[1]),
  );

  assert.deepEqual(requiredSecrets, new Set([
    "GOOGLE_CLIENT_ID",
    "REVENUECAT_SECRET_API_KEY",
    "REVENUECAT_WEBHOOK_AUTH",
    "REVENUECAT_WEBHOOK_SECRET",
    "SESSION_SECRET",
    "ACCESS_TEAM_DOMAIN",
    "ACCESS_AUD",
  ]));
});
