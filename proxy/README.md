# Wut Mutt identification proxy

A tiny Cloudflare Worker that holds the Anthropic API key server-side so the
iOS app never ships or stores it. The app POSTs a photo; the Worker adds the
key, calls Claude with a fixed prompt + schema, and passes the response back.

## Why

Anything bundled in an iOS binary is extractable. Putting the key behind this
Worker means a leaked build can't drain your Anthropic account, and the daily
cap stops one person from running up the bill.

The cap is keyed per IPv4 address, and per **/64** for IPv6 — see `rateSubject`
in `src/index.js`. Keying on a full IPv6 address doesn't work: phones rotate the
low 64 bits under privacy extensions, so each rotation would grant a fresh
budget.

## Deploy

```sh
cd proxy
npm install
npx wrangler login

# Secrets (never committed):
npx wrangler secret put ANTHROPIC_API_KEY   # your Anthropic key
npx wrangler secret put APP_TOKEN           # any long random string; the app sends it

# Recommended — per-IP daily rate cap:
npx wrangler kv namespace create RATE_KV
#   paste the printed id into wrangler.toml under [[kv_namespaces]] and uncomment

npx wrangler deploy
```

`deploy` prints a URL like `https://wutmutt-identify.<subdomain>.workers.dev`.

## Point the app at it

The app reads two values from its Info.plist, which are supplied by a
git-ignored xcconfig so your Worker URL and token never get committed:

1. `cp WutMutt/Config/Secrets.local.example.xcconfig \`
   `   WutMutt/Config/Secrets.local.xcconfig`
2. Edit `Secrets.local.xcconfig` and fill in the two lines:
   - `WMIdentifyProxyURL` — your deploy URL with `/identify`, e.g.
     `https:/$()/wutmutt-identify.<subdomain>.workers.dev/identify`
     (the `$()` is required — xcconfig treats a literal `//` as a comment)
   - `WMIdentifyAppToken` — the same `APP_TOKEN` you set above
3. Rebuild.

`Secrets.local.xcconfig` is listed in the repo's `.gitignore`. The committed
`Config.xcconfig` optionally includes it and defaults both values to empty, so
a fresh clone (without the secrets file) builds cleanly in bring-your-own-key
mode. When the values are present, the app routes through the proxy and the
"Connect Claude" key prompt never appears.

The `APP_TOKEN` in the app is a soft gate — it discourages casual abuse of the
endpoint but, like any bundled string, is extractable. The real protection is
the per-IP daily cap plus a spend limit set in the Anthropic Console.

## Errors

Failures return Anthropic's envelope shape with a `type` the app switches on,
so a capped or unreachable studio never turns into an invented breed reading:

| `error.type`          | HTTP | App shows                                    |
|-----------------------|------|----------------------------------------------|
| `rate_limit`          | 429  | "That's a wrap." — daily cap, back tomorrow   |
| `upstream_config`     | 502  | "The show is off the air." — key/billing      |
| `upstream_unavailable`| 503  | "Please stand by." — retryable                |
| `unauthorized`        | 401  | Generic off-air card                          |

Upstream 4xx is deliberately remapped to 502 with our own wording: Anthropic's
message can name the account or the key, and it isn't the viewer's problem.

## Breed logging

The Worker counts which breed names Claude returns, into an Analytics Engine
dataset (`BREEDS_AE` → `wutmutt_breeds`). Name, position in the list, and
percentage only — no IPs, no image data, nothing user-linked.

This exists to source the bundled breed photos against reality. Claude is
unconstrained, so it names crosses and type-categories the AKC doesn't
recognise — Goldendoodle, the pit-bull cluster — while plenty of AKC breeds may
never come up. Licensing 40 photos against a guessed list would waste much of
the work.

The binding is optional; remove it and the Worker runs unchanged. The dataset
is created on first write. Query it via Cloudflare's Analytics Engine SQL API,
where `blob1` is the name, `double1` the position (0 = lead breed) and
`double2` the percentage:

```sql
SELECT blob1 AS breed, COUNT() AS appearances, AVG(double2) AS avg_pct
FROM wutmutt_breeds
WHERE timestamp > NOW() - INTERVAL '30' DAY
GROUP BY breed
ORDER BY appearances DESC
```

Filter `double1 = 0` for lead breeds only — those are the ones whose photo
carries the detail screen. "a special guest" will appear in the results; it is
the deliberate wildcard, not a breed, and needs no photo.

## Model

`MODEL` at the top of `src/index.js` is `claude-sonnet-5`. Because it lives here
now, changing models is a `wrangler deploy`, not an App Store release.

Sonnet-tier suits the job — one small image in, one fixed schema out — and Opus
costs roughly double per scan for a task that isn't reasoning-bound. Sonnet 5
specifically, because `output_config` structured outputs require it (Sonnet 4.5
does not support them).

Thinking is explicitly disabled: it is on by default on current models and
shares the `max_tokens` budget with the response, so leaving it on risks a
truncated JSON body surfacing to the viewer as a false "off the air".

## Local test

Create `.dev.vars` **in an editor** (it's git-ignored) with these two lines:

```
ANTHROPIC_API_KEY = "sk-ant-..."
APP_TOKEN = "test-token"
```

Don't `echo` the key into the file — that writes it to your shell history in
plaintext, where it outlives the throwaway `.dev.vars` by months. Then:

```sh
npx wrangler dev
# then POST { "image": "<base64 jpeg>" }
#   to http://localhost:8787/identify with header x-wm-app-token: test-token
```

Same rule for `wrangler secret put`: let it prompt, or pipe from a variable
(`printf '%s' "$TOKEN" | npx wrangler secret put APP_TOKEN`) so the value never
appears as a command argument.
