# Module 11.4 — Logging with Loki

> Prometheus tells you an error rate rose; logs tell you **what the errors actually
> said**. **Loki** is "Prometheus for logs" — it indexes only a small set of
> **labels**, not the full log text, which makes it cheap to run at scale. This
> module covers Loki's architecture, **LogQL**, and the one rule that makes or breaks
> a Loki deployment: keep your labels low-cardinality.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 11.1](../01-observability-fundamentals/) and
[Docker Compose](https://docs.docker.com/compose/). No cloud.

## Learning objectives

By the end of this module you will be able to:

- Explain how Loki indexes **labels** (not full text) and why that makes it cheap.
- Define a **log stream** and reason about label cardinality in Loki.
- Write **LogQL** to filter, parse structured logs, and compute metrics from logs.
- Choose a log-collection agent (Promtail, Grafana Alloy, or the OTel Collector).
- Apply **structured logging** and set sensible retention and storage backends.

---

## 1. Concept

### The idea: index labels, not text

Traditional log systems (think Elasticsearch) index the **full content** of every log
line so you can search any word. That is powerful and *expensive* — the index often
dwarfs the logs themselves. Loki makes a different bet, borrowed straight from
Prometheus: **index only a small set of labels**, and store the raw log text as
compressed chunks in cheap object storage. Queries first use the tiny label index to
find the right **streams**, then brute-force scan just those chunks for your text.

The payoff is cost: Loki's index is small, so it is dramatically cheaper to operate
than a full-text system, and it uses the **same label model** as Prometheus — so
`{namespace="team-a", app="checkout"}` means the same thing for your logs as for your
metrics. The trade-off is that Loki is not a fast full-text search engine; it is a
*label-scoped grep over time*. For platform logging at volume, that trade is usually
the right one.

### Streams and labels

A **log stream** is a unique set of label key-values plus the ordered log lines that
carry it. `{namespace="team-a", app="checkout", level="error"}` is one stream;
changing any label value makes a different stream.

This is where Loki's golden rule lives, and it is the mirror image of the metrics
cardinality lesson:

> **Labels must be low-cardinality.** Every unique label-value combination is a
> separate stream with its own index entry and chunks. Put a high-cardinality field —
> `user_id`, `trace_id`, `request_path`, a raw IP — in a **label** and you create
> millions of tiny streams, which is the number-one way to make Loki fall over.

The fix: use a *few* bounded labels (namespace, app, level, cluster) for *routing*,
and keep the high-cardinality detail **inside the log line** (ideally as JSON), where
LogQL can filter and parse it at query time without paying the index cost.

### Architecture

Loki splits into components you can run as one binary (small) or scale out (large):

- **Distributor** — receives incoming logs from agents, validates them, and hashes
  each stream to the right ingester(s).
- **Ingester** — buffers log lines in memory per stream, then flushes compressed
  **chunks** and index to long-term storage. It also serves recent, not-yet-flushed
  data to queries.
- **Querier** — executes LogQL: consults the index, fetches the relevant chunks, and
  scans them. Fans out for parallelism.
- **Query frontend** (optional) — splits and queues large queries so they run in
  parallel and cache results.
- **Compactor** — compacts index files and enforces **retention** (deleting old data)
  in the backing store.

The backing store is **object storage** — S3, GCS, Azure Blob, or a local filesystem
for a lab. Loki's deployment modes are **single-binary** (everything in one process,
great for small setups and labs), **simple scalable** (read/write/backend split), and
**microservices** (each component separate, for very large scale). In the LGTM stack,
the **L** is Loki.

### Collecting logs: Promtail, Alloy, or OTel

Something has to read logs and push them to Loki:

- **Promtail** — Loki's classic agent. Runs as a DaemonSet, discovers Kubernetes Pod
  logs, attaches labels from Pod metadata, and pushes to Loki. Simple and purpose-built.
- **Grafana Alloy** — Grafana's newer, general-purpose collector (OTel-compatible)
  that supersedes Promtail for new deployments; it collects logs *and* metrics *and*
  traces.
- **The OpenTelemetry Collector** — if you already run OTel (Module 11.2), its
  `filelog` receiver plus a `loki` exporter sends logs to Loki through the same
  pipeline as your traces and metrics. One agent, all three signals.

For a platform standardizing on OTel, routing logs through the Collector keeps a
single telemetry pipeline. Promtail is the simplest starting point.

### LogQL

LogQL has two halves. A **log query** selects and filters lines:

- **Stream selector** (required): `{app="checkout", level="error"}` — uses the index.
- **Line filters**: `|= "timeout"` (contains), `!= "healthz"` (does not contain),
  `|~ "5\\d\\d"` (regex). These scan the chunk text.
- **Parsers and pipelines**: `| json`, `| logfmt`, `| pattern` extract fields from the
  line; then `| status >= 500`, `| line_format "{{.msg}}"`, `| label_format ...`.

A **metric query** wraps a log query in a function to produce a time series — this is
how logs become graphable and alertable:

```logql
# error lines per second for a service, computed FROM logs
rate({app="checkout"} |= "error" [5m])

# count by level, parsed from JSON
sum by (level) (count_over_time({app="checkout"} | json [5m]))
```

That metric-from-logs capability is why Loki pairs so naturally with Prometheus and
Grafana: you can alert on a log pattern the same way you alert on a metric.

---

## 2. Why it matters for platform engineering

- **Centralized logs are table stakes.** A platform running many teams' workloads
  needs one place to search logs, with consistent labels (`namespace`, `app`, `pod`)
  so any engineer can find any service's logs without bespoke setup.
- **The label rule is a multi-tenant guardrail.** A single team labeling logs by
  `request_id` can blow up the shared Loki's stream count for everyone. You enforce
  the label policy centrally — in the agent config, not by trusting each team.
- **Cheap logging changes what you can afford to keep.** Loki's economics let a
  platform retain more logs for longer than a full-text system would, which matters
  for incident forensics and audit.
- **Structured logging is a platform standard you set.** Mandating JSON logs with
  shared field names (and a `trace_id` field) is what makes logs queryable *and*
  correlatable with traces (Module 11.5).

---

## 3. Mental model

Think of Loki as a **filing cabinet indexed only by the label on each folder**. The
label index is tiny, so finding the right folders is instant; then you *read through*
just those folders for the text you want.

```text
   query: {app="checkout", level="error"} |= "timeout"
            │                                   │
            ▼                                   ▼
     1) use the LABEL INDEX              2) grep the CHUNKS of
        (tiny) to pick streams             only those streams for "timeout"
   ┌──────────────────────────┐        ┌───────────────────────────────┐
   │ {app=checkout,level=error}│──────▶│ ...raw JSON log lines (chunks) │
   │ {app=checkout,level=info} │  skip  │  in cheap object storage       │
   │ {app=payments,level=error}│  skip  └───────────────────────────────┘
   └──────────────────────────┘

   Labels = how you FIND logs (keep few, bounded).
   Line content (JSON) = the DETAIL you parse at query time (put IDs here).
```

Rule of thumb: **if a field has more than a few dozen possible values, it is log
*content*, not a label.**

---

## 4. Minimal implementation

The smallest useful setup is one agent tailing a file into Loki, then a LogQL query.
Even without Kubernetes, Loki ingests anything pushed to its HTTP API. A structured
log line is just JSON on stdout:

```json
{"ts":"2026-02-01T10:00:03Z","level":"error","service":"checkout","route":"/pay","status":500,"trace_id":"a1b2c3","msg":"payment gateway timeout"}
```

An agent attaches a *few* labels and ships the raw line:

```yaml
# promtail (excerpt): low-cardinality labels only; detail stays in the line
scrape_configs:
  - job_name: app
    static_configs:
      - targets: [localhost]
        labels:
          service: checkout      # a label  (bounded)
          __path__: /var/log/app/*.log
    pipeline_stages:
      - json: { expressions: { level: level } }
      - labels: { level: {} }    # promote ONLY level (info/warn/error) to a label
```

Now LogQL answers questions, with identifiers parsed from the line — never indexed:

```logql
{service="checkout"} | json | level="error"          # all error lines
{service="checkout"} | json | status >= 500           # server errors by parsed field
rate({service="checkout"} | json | level="error" [5m])# error lines per second
```

Notice `status` and `trace_id` are **parsed at query time** from JSON — they never
become labels, so cardinality stays flat no matter how many distinct values appear.
The lab runs exactly this stack with Docker Compose and Grafana Explore.

---

## 5. Hands-on lab

You will run Loki, Promtail, Grafana, and a JSON log generator with Docker Compose,
then use LogQL in Grafana Explore to filter logs, parse structured fields, and
compute an error rate from log lines — while keeping labels low-cardinality.

➡️ **[Start the lab: LogQL over structured logs](./lab/README.md)**

---

## 6. Production considerations

- **Enforce the label policy centrally.** Cap labels to a known, bounded set in the
  agent config and reject or relabel high-cardinality fields. Watch Loki's active
  stream count; a spike is a tenant about to hurt everyone.
- **Back it with object storage and set retention.** Filesystem is for labs. Use
  S3/GCS/Azure, and configure the compactor's retention per tenant — logs are the
  signal you keep longest for forensics but cannot keep forever.
- **Mandate structured logging.** JSON (or logfmt) with shared field names
  (`level`, `service`, `trace_id`, `msg`) makes logs parseable and correlatable.
  Free-text logs are a query dead end at scale.
- **Include a `trace_id` field.** It is the join key from a log line to its trace in
  Tempo (Module 11.5). Bake it into the logging library on the golden path.
- **Multi-tenancy and quotas.** Use Loki's tenant IDs to isolate teams and set
  per-tenant ingestion and stream limits, so one noisy team cannot starve the rest.
- **Do not treat Loki as full-text search.** Queries that scan huge time ranges with
  no label selector are slow and costly. Teach teams to anchor queries with labels
  and a tight time range.

## 7. Common mistakes

- **High-cardinality labels.** — Labeling by `request_id`, `trace_id`, user, or raw
  path creates millions of streams and cripples Loki. *Fix:* few bounded labels; keep
  identifiers in the JSON line and parse them with `| json` at query time.
- **Unstructured, free-text logs.** — `| json`/`| logfmt` cannot parse them, so you
  are stuck with brittle substring filters. *Fix:* emit structured logs with
  consistent keys.
- **No label selector in LogQL.** — `{} |= "error"` over all streams and all time
  scans everything and times out. *Fix:* always start with a label selector and a
  bounded time range.
- **Expecting Elasticsearch-style relevance search.** — Loki is label-scoped grep,
  not a ranked full-text engine. *Fix:* design labels and structured fields for the
  queries you actually run.
- **Filesystem storage in production.** — It does not scale or survive node loss, and
  retention is awkward. *Fix:* object storage (S3/GCS) with the compactor managing
  retention.
- **Forgetting the trace join key.** — Logs with no `trace_id` cannot be linked to
  traces, breaking correlation. *Fix:* propagate and log `trace_id` everywhere.

## 8. Assessment

**Knowledge checks**

1. What does Loki index, and how does that differ from a full-text log system?
2. What is a log stream, and why must labels be low-cardinality?
3. Where should a `trace_id` live — in a Loki label or in the log line? Why?
4. Write a LogQL query for the per-second rate of error lines from `app="checkout"`.
5. Name two ways to collect logs into Loki and when you'd pick each.

**Concept exercise**

> Explain to a team why they should **not** add a `user_id` label to their logs, and
> what to do instead so they can still find a specific user's requests — **without
> using the words "cardinality" or "stream."**

**Trade-off / debugging exercise**

> After a team deployed a new logging config, Loki's memory ballooned and queries
> slowed to a crawl, though log *volume* barely changed. Their config promotes
> `level`, `service`, **and `request_id`** to labels. Explain the root cause, predict
> what the active-stream count did, and give the one-line fix.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Loki indexes a small set of labels and stores raw log text as compressed
  chunks; a full-text system indexes every token in every line. Loki's index is far
  smaller and cheaper, at the cost of not being a fast relevance search engine.
- **Q2:** A stream is a unique label set plus its ordered lines. Each unique label
  combination is a separate indexed stream, so high-cardinality labels multiply
  streams and overwhelm the index and ingesters.
- **Q3:** In the log line (as a JSON field). As a label it would be astronomically
  high-cardinality; in the line it is parsed at query time for free and still lets you
  jump to the trace.
- **Q4:** `rate({app="checkout"} |= "error" [5m])` (or
  `rate({app="checkout"} | json | level="error" [5m])`).
- **Q5:** Promtail (simple, Kubernetes-native log DaemonSet) or Grafana Alloy / the
  OTel Collector (one agent for logs+metrics+traces, ideal if you already run OTel).
- **Debugging:** `request_id` is unbounded, so promoting it to a label creates a new
  stream per request — the active-stream count exploded into the millions, blowing up
  ingester memory and index size and slowing every query. Fix: stop labeling by
  `request_id` (drop it from the `labels` stage); keep it in the JSON line and parse
  with `| json` when needed.

</details>

---

## 9. Further reading

- Grafana — [Loki documentation](https://grafana.com/docs/loki/latest/)
- Grafana — [LogQL](https://grafana.com/docs/loki/latest/query/) and
  [log queries](https://grafana.com/docs/loki/latest/query/log_queries/)
- Grafana — [Loki labels and cardinality best practices](https://grafana.com/docs/loki/latest/get-started/labels/)
- Grafana — [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) and
  [Grafana Alloy](https://grafana.com/docs/alloy/latest/)
- Grafana — [Loki storage and retention](https://grafana.com/docs/loki/latest/operations/storage/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.3 — Metrics with Prometheus](../03-metrics-with-prometheus/)
· _Next:_ [Module 11.5 — Distributed Tracing with Tempo →](../05-distributed-tracing-with-tempo/)
