# Bookerize proxy

A Cloudflare Worker whose only job is to hold the Gemini API key.

A key compiled into a Flutter app can be pulled out of the IPA in minutes. Here
the key is a Worker secret, and each device carries a **token** — a name on a
list — that you can revoke on its own without touching the key.

The prompts live here too, so their wording (the main lever on answer quality)
and the model can change with a redeploy rather than an App Store release.

## Endpoints

| | |
|---|---|
| `POST /v1/word` | `{ word, sentence }` → what the word means *in that sentence* |
| `POST /v1/explain` | `{ sentence }` → the same sentence in plainer English |
| `GET /health` | liveness, no token needed |

Both send `Authorization: Bearer <token>` and receive a stream:

```
data: {"text":"It means "}
data: {"text":"give and take."}
data: [DONE]
```

Errors arrive the same way — `data: {"error":"..."}` — because by the time an
answer fails, the HTTP status has usually already been sent.

## Setting it up

```bash
cd proxy
npm install
npx wrangler login

# The Gemini key from aistudio.google.com. Never goes in a file.
npx wrangler secret put GEMINI_API_KEY

# Comma-separated device tokens. Generate one per person:
#   node -e "console.log(crypto.randomUUID())"
npx wrangler secret put ALLOWED_TOKENS

npx wrangler deploy
```

Then build the app against it:

```bash
flutter run --dart-define=BOOKERIZE_PROXY_URL=https://bookerize-proxy.<you>.workers.dev \
            --dart-define=BOOKERIZE_TOKEN=<one-of-those-tokens>
```

Without both defines the app runs fine and simply doesn't offer the AI features —
the offline dictionary needs neither.

## Running it locally

```bash
cp .dev.vars.example .dev.vars   # then put real values in it; it is gitignored
npm run dev
```

## Tests

```bash
npm test
```

These cover the parts that must be right before a key exists: SSE parsing across
awkward chunk boundaries, token checking, input caps, and the full request path
against a fake Gemini. They need no key and no network.

## Costs and limits

Rate limiting is per token, 20 requests a minute, set in `wrangler.jsonc`.
`max_output_tokens` is capped at 320 in `src/gemini.js`, so no single request can
run away. Answers are also cached on the device, so the same question is never
paid for twice.
