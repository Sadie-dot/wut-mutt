# App Store Connect — App Privacy answers

What to enter under **App Store Connect → your app → App Privacy**, and why.
Recorded here because Lemon Pig's answers were only ever in a chat transcript,
which made them impossible to check against later.

Not legal advice. Where a question is a judgement call rather than a fact about
the code, it says so.

---

## The architecture these answers describe

Every reveal posts `{ "image": "<base64 jpeg>" }` to the Cloudflare Worker at
`proxy/src/index.js`, which forwards it to Anthropic and returns the result.
Three things happen server-side that bear on privacy:

| What | Where | Retained | Linked to the user? |
|---|---|---|---|
| The photo | forwarded to Anthropic | **no copy kept** | — |
| Rate-limit counter | `RATE_KV`, key `rl:<ip>:<date>` | ~25 h (`expirationTtl: 90000`) | keyed to IP |
| Breed names | `BREEDS_AE` Analytics Engine | ~90 d (Cloudflare default) | **no** — name, position, pct only |

The two are deliberately never joined: `logBreeds()` writes no IP, and the
rate-limit key contains no breed data. If that ever changes, this file is wrong.

Bring-your-own-key builds bypass the Worker entirely — the photo goes straight
from the device to Anthropic, so neither the rate limit nor the breed count
applies.

---

## Answers

**Do you or your third-party partners collect data from this app?** → **Yes**

### Declare: Usage Data → Other Usage Data

- **Linked to the user's identity?** → **No**
- **Used for tracking?** → **No**
- **Purpose** → **Analytics**

This is the breed-name log. Apple has no "things a model returned about your
photo" category; the breed name is a record of app activity, and Other Usage
Data is the catch-all for exactly that. It is not Search History — the user
never types a query — which is where Lemon Pig's equivalent landed, and the
difference is real rather than cosmetic.

### Do NOT declare: Photos (User Content)

Apple defines "collect" as transmitting data off-device in a way that lets you
access it *for longer than needed to service the request*. The Worker keeps no
copy of the photo, so it is not collected under that definition. This matches
what Lemon Pig declared for the same architecture.

Two things would flip this and require declaring **User Content → Photos or
Videos**: caching or logging images in the Worker, or persisting a scan history
on the device that syncs anywhere.

### Judgement call: the IP rate-limit counter

**Recommendation: declare it** as **Identifiers → Device ID**, *not linked to
identity*, purpose **App Functionality**.

The argument for declaring: the counter outlives the request it services — ~25
hours — and it is keyed to an IP address, so it is not obviously covered by the
"only as long as necessary" carve-out. Rate limiting also runs on every reveal,
so it can't lean on Apple's exception for collection that is infrequent and
optional.

The argument against: an IP address identifies a network rather than a device,
Apple's taxonomy has no IP entry, and the counter is a single integer used only
to cap abuse.

**Lemon Pig did not declare this**, having shipped the same design. If you take
the recommendation here, consider updating Lemon Pig's label to match — not
because Apple will cross-reference them, but because two answers to one question
means one of them is wrong.

Under-disclosure is a routine rejection reason; over-disclosure costs a line on
the product page and nothing else. That asymmetry is why the recommendation
leans toward declaring.

### Tracking

**Does your app track users?** → **No**

Nothing is linked to identity, there is no advertising, no third-party SDKs, and
no data is shared with data brokers. The product page should end up with a
**Data Not Linked to You** section and **no** "Data Used to Track You" section.

---

## The two URLs Apple requires

| Field | Paste this |
|---|---|
| Privacy Policy URL | `https://wut-mutt.pages.dev/privacy-policy` |
| Support URL | `https://wut-mutt.pages.dev/` |

Note the privacy URL has **no `.html`**. Cloudflare Pages treats the
extension-less path as canonical and 308-redirects `privacy-policy.html` to it;
both work, but give Apple the one that doesn't redirect.

Hosted on Cloudflare Pages (project `wut-mutt`) rather than GitHub Pages,
because the `wut-mutt` repo is private and Pages cannot serve from it. The
source of truth is `site/` in this repo; redeploy with:

```
npx wrangler pages deploy ../site --project-name wut-mutt --branch main
```

run from `proxy/` (which is where wrangler is installed). `docs/` is not
deployed — these notes are internal.

---

## Keep this in sync

Re-check this file whenever `proxy/src/index.js` changes what it stores, and
whenever the app starts persisting anything beyond `wm-star-idx` (an integer
naming which cover star was shown last, which contains nothing about the user).
