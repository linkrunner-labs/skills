---
name: linkrunner-webhooks
description: >-
  Set up a Linkrunner webhook receiver in a backend app to get real-time
  install and signup attribution events - detect the backend framework
  (Express, Fastify, Next.js API routes, NestJS, Flask, FastAPI, Django,
  etc.), add a route that verifies the linkrunner-key header, and handle the
  payload idempotently. Use when someone asks to set up Linkrunner webhooks,
  receive install/signup webhooks, or handle a Linkrunner webhook in their
  backend.
metadata:
  category: integrations
  slug: webhooks
  docs: https://docs.linkrunner.io/features/webhooks
---

# Linkrunner - Webhooks integration

You are adding a **server-side webhook receiver** for Linkrunner attribution
events to a backend project. Linkrunner sends a POST request to a URL you
configure in the dashboard whenever an install is attributed or a user signs
up. Work in this order and **inspect the project before editing** - do not
paste snippets blindly.

## 0. Before you touch anything

1. Detect the backend framework and language: `package.json` for
   `express` / `fastify` / `next` / `@nestjs/core`; `requirements.txt` or
   `pyproject.toml` for `flask` / `fastapi` / `django`; adjust for anything
   else you find. Do not assume - read the manifest.
2. Find where routes/handlers already live (an existing `routes/`, `api/`, or
   `controllers/` tree; for Next.js, `app/api/*/route.ts` or
   `pages/api/*.ts`; for Django, `urls.py`) and add the webhook route there,
   matching the project's existing conventions (routing style, error
   handling, logging).
3. Find how secrets are configured (`.env`, a config module, a secrets
   manager) - the project's private key belongs there, never hardcoded.
4. Get the project's **private key** from the dashboard
   ([Settings -> Webhooks](https://dashboard.linkrunner.io/settings?s=webhooks))
   if it isn't already in the project's env as something like
   `LINKRUNNER_PRIVATE_KEY`.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "Set up Linkrunner webhooks" / "receive install/signup events" | `references/setup.md` (dashboard config + payload) then `references/handler.md` (write the receiver) |
| "Verify my endpoint works" | `scripts/verify-webhook.sh` |
| "Not receiving webhooks" / "getting 401s" | Re-check header verification in `references/handler.md`; troubleshooting notes in `references/setup.md` |

## 2. Golden rules

- Verify the `linkrunner-key` header against the stored private key **before**
  processing anything, using a constant-time compare. This is the only
  authentication Linkrunner webhooks use - there is no HMAC signature scheme,
  so don't invent one.
- Respond with a 2xx status as fast as possible (well under the 5s Linkrunner
  expects). Acknowledge first, then do the real work asynchronously (queue,
  background job, `setImmediate`/background task) - Linkrunner does not wait
  for your processing to finish.
- Make handling idempotent: dedupe on `event_type` + `campaign_id` + `user_id`
  (when present) + a device id (`gaid`/`idfa`) or timestamp. Linkrunner
  retries up to 3 times (immediate, +1s, +2s) on any non-2xx response, so the
  same event can arrive more than once.
- Branch on `event_type` (`"install"` | `"signup"`) - never assume every
  payload has a `user_id`. Identity fields (`user_id`, `name`, `phone`,
  `email`) only arrive on `signup`; `install` gives you device ids
  (`gaid`/`idfa`) to match against the later signup.
- Log failures and alert on repeated ones - after 3 failed attempts Linkrunner
  stops retrying and marks the webhook failed.

## 3. Finish

After writing the handler, run
`scripts/verify-webhook.sh <url> <linkrunner-key>` to POST a sample install
and signup payload and confirm both return 2xx. Report which checks passed,
and remind the user to:
- paste the endpoint URL into the dashboard (Settings -> Webhooks)
- confirm the key used in the handler matches the private key shown there

## References

- `references/setup.md` - dashboard config, events and when they fire, headers, full payload field list
- `references/handler.md` - idiomatic receiver implementations (Express, FastAPI, Flask) with verification, idempotency, and async processing
