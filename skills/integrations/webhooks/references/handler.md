# Webhooks - implementing the receiver

Source of truth: https://docs.linkrunner.io/features/webhooks

Every example below does the same five things, in order:

1. Read the raw JSON body.
2. Verify the `linkrunner-key` header against the stored private key with a
   **constant-time compare** (not `===`/`==`) - a plain string compare leaks
   timing information an attacker could use to guess the key byte by byte.
   This is the only auth mechanism Linkrunner webhooks use; there is no HMAC
   signature to verify instead.
3. Branch on `event_type` (`"install"` | `"signup"`).
4. Upsert idempotently, keyed on `event_type` + `campaign_id` + `user_id`
   (when present) + a device id (`gaid`/`idfa`) or timestamp - Linkrunner
   retries up to 3 times on any non-2xx response, so the same event can
   arrive more than once.
5. Return 2xx immediately, then hand real processing off to a queue/background
   task rather than doing it inline before responding.

Adapt variable names, the storage layer, and the async dispatch mechanism to
match what's already in the project - these are shapes to follow, not files
to copy verbatim.

## Node.js / Express

```javascript
const crypto = require('crypto');

const PRIVATE_KEY = process.env.LINKRUNNER_PRIVATE_KEY;

function isValidKey(received) {
  if (!received) return false;
  const a = Buffer.from(received);
  const b = Buffer.from(PRIVATE_KEY);
  // timingSafeEqual throws on length mismatch, so guard that first.
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

// app.use(express.json()) must run before this route so req.body is parsed.
app.post('/webhooks/linkrunner', (req, res) => {
  if (!isValidKey(req.headers['linkrunner-key'])) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const event = req.body;

  // Ack immediately; do the real work off the request/response cycle.
  res.status(200).json({ received: true });

  setImmediate(() => handleWebhookEvent(event).catch((err) => {
    console.error('linkrunner webhook processing failed', err);
  }));
});

async function handleWebhookEvent(event) {
  const dedupeKey = [
    event.event_type,
    event.campaign_id,
    event.user_id ?? event.gaid ?? event.idfa ?? event.attributed_on,
  ].join(':');

  if (await alreadyProcessed(dedupeKey)) return;

  switch (event.event_type) {
    case 'install':
      // event.user_id/name/phone/email are NOT present here - only gaid/idfa.
      await recordInstall(event);
      break;
    case 'signup':
      // event.user_id is now populated; link it to the install via gaid/idfa.
      await recordSignup(event);
      break;
    default:
      console.warn('unknown linkrunner event_type', event.event_type);
      return;
  }

  await markProcessed(dedupeKey);
}
```

For a real deployment, swap `setImmediate` for whatever the project already
uses to defer work (a job queue like BullMQ/SQS, a `pg_cron`/outbox table,
etc.) - the point is that `res.status(200)` returns before the slow work
starts, not the specific mechanism.

## Python / FastAPI

```python
import hmac
import os
from fastapi import BackgroundTasks, FastAPI, Header, HTTPException, Request

app = FastAPI()
PRIVATE_KEY = os.environ["LINKRUNNER_PRIVATE_KEY"]


def is_valid_key(received: str | None) -> bool:
    if not received:
        return False
    # compare_digest is constant-time and handles length differences safely.
    return hmac.compare_digest(received, PRIVATE_KEY)


@app.post("/webhooks/linkrunner")
async def linkrunner_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    linkrunner_key: str | None = Header(default=None),
):
    if not is_valid_key(linkrunner_key):
        raise HTTPException(status_code=401, detail="Unauthorized")

    event = await request.json()

    # Queue the real work and return 2xx immediately.
    background_tasks.add_task(handle_webhook_event, event)
    return {"received": True}


async def handle_webhook_event(event: dict) -> None:
    dedupe_key = ":".join(
        str(v)
        for v in (
            event.get("event_type"),
            event.get("campaign_id"),
            event.get("user_id") or event.get("gaid") or event.get("idfa") or event.get("attributed_on"),
        )
    )

    if await already_processed(dedupe_key):
        return

    event_type = event.get("event_type")
    if event_type == "install":
        # user_id/name/phone/email are NOT present here - only gaid/idfa.
        await record_install(event)
    elif event_type == "signup":
        # user_id is now populated; link it to the install via gaid/idfa.
        await record_signup(event)
    else:
        return

    await mark_processed(dedupe_key)
```

## Python / Flask

```python
import hmac
import os
from flask import Flask, request, jsonify
from threading import Thread

app = Flask(__name__)
PRIVATE_KEY = os.environ["LINKRUNNER_PRIVATE_KEY"]


def is_valid_key(received):
    return bool(received) and hmac.compare_digest(received, PRIVATE_KEY)


@app.post("/webhooks/linkrunner")
def linkrunner_webhook():
    if not is_valid_key(request.headers.get("linkrunner-key")):
        return jsonify(error="Unauthorized"), 401

    event = request.get_json(force=True)

    # Ack immediately; hand the real work to a background thread/queue.
    Thread(target=handle_webhook_event, args=(event,)).start()
    return jsonify(received=True), 200


def handle_webhook_event(event):
    dedupe_key = ":".join(
        str(v)
        for v in (
            event.get("event_type"),
            event.get("campaign_id"),
            event.get("user_id") or event.get("gaid") or event.get("idfa") or event.get("attributed_on"),
        )
    )

    if already_processed(dedupe_key):
        return

    event_type = event.get("event_type")
    if event_type == "install":
        record_install(event)
    elif event_type == "signup":
        record_signup(event)
    else:
        return

    mark_processed(dedupe_key)
```

`Thread(...)` is the minimal illustration - in production, prefer a real task
queue (Celery, RQ, etc.) so processing survives a worker restart.

## Framework notes

- **Next.js API routes / route handlers**: read the header via
  `request.headers.get('linkrunner-key')`, `await request.json()` for the
  body, and dispatch the heavy work to a queue rather than `await`-ing it
  inline - serverless functions don't have a long-lived background thread to
  fire-and-forget into.
- **NestJS**: wrap the same logic in a controller method with a guard that
  does the `linkrunner-key` check, so it's reusable and testable separately
  from the handler.
- **Django**: use a plain function-based view (`csrf_exempt`, since this is a
  server-to-server POST with its own auth) or DRF `APIView`; dispatch heavy
  work via Celery rather than inline.

Whatever the stack, keep the three invariants: constant-time key check,
idempotent upsert, fast 2xx before the slow work.
