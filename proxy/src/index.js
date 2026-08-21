// Wut Mutt breed-identification proxy.
//
// Holds the Anthropic API key server-side so the iOS app never ships or
// stores it. The app POSTs { image } to /identify; the prompt, model, and
// output schema live HERE so the endpoint can't be repurposed as a general
// Claude proxy. Responses are passed through in the Anthropic Messages
// format the app already parses.
//
// Errors carry a machine-readable `type` alongside the human message so the
// app can tell "the studio is dark until tomorrow" from "we lost the feed"
// and say the right thing — it must never quietly invent a breed reading.
//
// Secrets (set with `npx wrangler secret put <NAME>`):
//   ANTHROPIC_API_KEY  — required
//   APP_TOKEN          — recommended; the app sends it as x-wm-app-token
// Optional bindings/vars (see wrangler.toml):
//   RATE_KV            — KV namespace enabling the per-IP daily cap
//   DAILY_CAP          — reveals per IP per day (default 40)
//   BREEDS_AE          — Analytics Engine dataset counting which breed names
//                        Claude returns (names only, never anything user-linked)

// Sonnet-tier is the right shape for this job: one small image in, one fixed
// schema out. Sonnet 5 specifically, because `output_config` structured
// outputs need it — claude-sonnet-4-5 does not support them.
const MODEL = "claude-sonnet-5";
const MAX_TOKENS = 2500;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/identify") {
      return err("not_found", "Not found.", 404);
    }
    if (env.APP_TOKEN && request.headers.get("x-wm-app-token") !== env.APP_TOKEN) {
      return err("unauthorized", "Unauthorized.", 401);
    }

    // Per-IP daily cap (skipped gracefully when no KV namespace is bound).
    // The message is a formality for anyone reading the wire — the app owns
    // the intermission card's copy and never displays what's sent here.
    if (env.RATE_KV) {
      const ip = request.headers.get("cf-connecting-ip") || "unknown";
      const key = `rl:${rateSubject(ip)}:${new Date().toISOString().slice(0, 10)}`;
      const used = parseInt((await env.RATE_KV.get(key)) || "0", 10);
      const cap = parseInt(env.DAILY_CAP || "40", 10);
      if (used >= cap) {
        return err("rate_limit", "Daily reveal cap reached.", 429);
      }
      await env.RATE_KV.put(key, String(used + 1), { expirationTtl: 90000 });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return err("bad_request", "Body must be JSON.", 400);
    }

    const image = body.image;
    if (typeof image !== "string" || image.length < 100 || image.length > 8_000_000) {
      return err("bad_request", "Missing or oversized image.", 400);
    }
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(image.slice(0, 4000))) {
      return err("bad_request", "Image must be base64 JPEG.", 400);
    }

    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(anthropicRequest(image)),
    });

    // Pass the upstream body through unchanged on success. On failure, don't
    // leak Anthropic's wording (it can name the account or the key) — map it
    // to our own type so the app picks the right screen.
    const raw = await upstream.text();
    if (upstream.ok) {
      logBreeds(env, raw);
      return new Response(raw, {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    // Upstream 429 is Anthropic throttling this account — transient, and
    // nothing like the viewer's daily cap. Reporting it as rate_limit used
    // to put the "come back tomorrow" card on a hiccup that clears in
    // seconds; it belongs with the retryable outages instead.
    if (upstream.status === 429) {
      return err("upstream_unavailable", "The studio isn't answering. Try again in a moment.", 503);
    }
    // 401/403 (bad or revoked key) and 400 (bad request) are the developer's
    // problem, not the viewer's, and there is nothing they can do but wait.
    if (upstream.status >= 400 && upstream.status < 500) {
      return err("upstream_config", "The show is off the air. We're working on it.", 502);
    }
    return err("upstream_unavailable", "The studio isn't answering. Try again in a moment.", 503);
  },
};

// Who the daily cap applies to. IPv4 is used whole; IPv6 collapses to its /64.
//
// macOS and iOS rotate the low 64 bits of an IPv6 address under privacy
// extensions, so keying on the full address hands a fresh daily budget to
// anyone whose OS re-rolls it — no malice required. Setting this app up
// produced two different full addresses from one machine inside an afternoon,
// which would have been two separate 40-reveal budgets.
//
// A /64 is the standard per-site allocation, so it stays put. The trade-off is
// that everyone behind one /64 now shares a budget: the household on a
// residential line, but potentially more on carrier or campus networks.
function rateSubject(ip) {
  if (!ip.includes(":")) return ip;
  return ip.split(":").slice(0, 4).join(":") + "::/64";
}

// Counts which breed names Claude actually returns, so the bundled photo set
// can be sourced against real frequency rather than a guess at AKC's list.
// That guess would be wrong in both directions: Claude is unconstrained, so it
// names crosses and type-categories AKC doesn't recognise (Goldendoodle, the
// pit-bull cluster) while plenty of AKC breeds may never come up at all.
//
// Records the name, its position in the list, and its percentage. No IPs, no
// image data, nothing user-linked — the same posture as Lemon Pig's
// logDiscovery. Best-effort by design: no binding or a malformed response
// means no log, and analytics must never break a reveal.
function logBreeds(env, rawResponse) {
  if (!env.BREEDS_AE) return;
  try {
    const message = JSON.parse(rawResponse);
    const text = (message.content || []).find((b) => b.type === "text")?.text;
    const result = JSON.parse(text);
    if (!result.isDog || !Array.isArray(result.breeds)) return;
    result.breeds.forEach((breed, position) => {
      const name = String(breed?.name ?? "").trim().toLowerCase().slice(0, 96);
      if (!name) return;
      env.BREEDS_AE.writeDataPoint({
        indexes: [name],
        blobs: [name],
        doubles: [position, Number(breed?.pct) || 0],
      });
    });
  } catch {
    // Swallow — a logging failure must not affect the response.
  }
}

function err(type, message, status) {
  return new Response(JSON.stringify({ type: "error", error: { type, message } }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Mirrors BreedIdentifier.swift's bring-your-own-key request — keep the two
// in sync when the prompt or schema changes.
function anthropicRequest(imageBase64) {
  const prompt = `Analyze this photo for Wut Mutt, a playful dog-breed app themed as a 1980s TV soap opera.

Rules:
- If no real live dog is present, set isDog false, certainty 99, breeds to an empty array, dogSize "unclear" and dogCoat "flat".
- Otherwise report the breeds you actually see — 1 to 4 of them, "pct" integers summing to exactly 100, most confident first. Accuracy beats drama: a clearly purebred dog is ONE breed at 100, a clear two-breed cross is two. Never pad the cast with breeds you don't see.
- Named crosses are real answers: when the dog reads as a recognizable designer cross (Labradoodle, Goldendoodle, Bernedoodle, Cockapoo, Maltipoo, and kin), bill the cross by name as the lead rather than splitting it into its parents. A parent breed may still appear in the supporting cast when its traits show through.
- But never guess WHICH cross: doodle variants mostly differ by coat color, and an off-color doodle (a gray Goldendoodle exists) is visually indistinguishable from its cousins. When the poodle half is plain but the other half isn't, bill the visible parent (Poodle) and give the mystery to the Guest Star — the wrong variant on a card is worse than an honest mystery.
- The bully breeds (American Pit Bull Terrier, American Staffordshire Terrier, Staffordshire Bull Terrier, American Bully) are near-identical on camera and share one ancestor. Name a specific one only when the read is genuinely clear; otherwise bill "Bull-and-Terrier" — the historic type they all descend from — and give remaining doubt to the Guest Star. Never bill several of them together: that is one visual signal counted twice.
- Never name wolves or wolf hybrids: a wolfy look (huskies have one) is not evidence of wolf ancestry, and no photo can establish it.
- Names are billing: keep them plain — "Standard Poodle", never "Poodle (Standard)". No parentheses, no "Mix" suffixes, no qualifiers inside a breed name.
- "certainty" is 40-99: how confident the visual breed read is.
- "dogSize" describes THIS animal, not its breeds' typical build: "large" or "small" only when it plainly reads that way, otherwise "unclear". A large-breed puppy is "small".
- "dogCoat" is "flat" or "fluffy" for the coat actually visible in the photo.
- "tagline" is a melodramatic soap-opera character description, e.g. "The brooding lead with a hidden past".
- "size"/"energy"/"drool"/"floof" are 1-3 word ratings.
- "clues" are 3 short visual details seen in THIS photo.
- "fact" is a real, accurate, fun breed fact in 1-2 sentences. Never invent facts.
- If the mix is uncertain, the last breed may be a wildcard named "Guest Star".
- The Guest Star's "size"/"energy"/"drool"/"floof" are playful mysteries in a fabulous register — like "Perfect", "Dreamy", "Effortless", "Inspired" — never real measurements. It is a fabulous mystery in the family tree — an unnamed ancestor, not a sibling and not a breed.`;

  return {
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: "You identify dog breeds from photos for Wut Mutt, a playful dog-breed app themed as a 1980s TV soap opera.",
    // Sonnet 5 thinks by default, and max_tokens caps thinking plus response
    // together — a schema-constrained read of one photo doesn't need it, and
    // the truncated JSON would surface as a false "off the air".
    thinking: { type: "disabled" },
    output_config: { format: { type: "json_schema", schema: verdictSchema() } },
    messages: [{
      role: "user",
      content: [
        { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
        { type: "text", text: prompt },
      ],
    }],
  };
}

// A schema rather than "respond with strict JSON" prompting: the app used to
// fall back to a canned episode whenever a single field came back missing.
function verdictSchema() {
  const str = { type: "string" };
  const breed = {
    type: "object",
    properties: {
      name: str,
      pct: { type: "integer" },
      tagline: str,
      size: str,
      energy: str,
      drool: str,
      floof: str,
      clues: { type: "array", items: str },
      fact: str,
    },
    required: ["name", "pct", "tagline", "size", "energy", "drool", "floof", "clues", "fact"],
    additionalProperties: false,
  };
  return {
    type: "object",
    properties: {
      isDog: { type: "boolean" },
      certainty: { type: "integer" },
      // What the photo showed, for the analyzing screen's closing question.
      // The app decodes these as optional, so a build newer than this Worker
      // degrades to its original question rather than failing the reveal.
      dogSize: { type: "string", enum: ["large", "small", "unclear"] },
      dogCoat: { type: "string", enum: ["flat", "fluffy"] },
      breeds: { type: "array", items: breed },
    },
    required: ["isDog", "certainty", "dogSize", "dogCoat", "breeds"],
    additionalProperties: false,
  };
}
