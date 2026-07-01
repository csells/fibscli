# Analytics

The Worker records usage and reliability metrics with Workers Analytics Engine.
Metrics are emitted at bounded lifecycle points, not for every frame.

Durable Objects are not required for these metrics. Historical concurrency can
be derived from `session_start` and `session_close` events; exact live global
state is out of scope for the first implementation.

## Event Types

- `bridge_request`
- `session_start`
- `tcp_connected`
- `tcp_connect_failed`
- `session_close`
- `session_reject`
- `limit_hit`
- `bridge_error`

## Blob Columns

The Worker writes blobs in this order:

1. event type
2. environment
3. version
4. route
5. result
6. reject reason
7. close side
8. close reason
9. colo
10. country
11. origin category
12. client kind

Payload content is never recorded.

## Double Columns

The Worker writes doubles in this order:

1. request count
2. accepted session count
3. rejected session count
4. TCP connect latency in milliseconds
5. time to first FIBS byte in milliseconds
6. session duration in milliseconds
7. browser-to-FIBS message count
8. FIBS-to-browser message count
9. browser-to-FIBS byte count
10. FIBS-to-browser byte count
11. close count
12. error count
13. idle timeout count
14. oversize-message count

## Starter Queries

Analytics Engine may sample rows. Count and sum queries should weight values
with `_sample_interval`.

Sessions per hour:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
  sum(_sample_interval * double2) AS accepted_sessions
FROM fibs_proxy_events
WHERE blob1 = 'bridge_request'
GROUP BY hour
ORDER BY hour DESC
```

Sessions per day:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL '1' DAY) AS day,
  sum(_sample_interval * double2) AS accepted_sessions
FROM fibs_proxy_events
WHERE blob1 = 'bridge_request'
GROUP BY day
ORDER BY day DESC
```

Accepted vs rejected sessions:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
  sum(_sample_interval * double2) AS accepted_sessions,
  sum(_sample_interval * double3) AS rejected_sessions
FROM fibs_proxy_events
WHERE blob1 = 'bridge_request'
GROUP BY hour
ORDER BY hour DESC
```

Reject reasons:

```sql
SELECT
  blob6 AS reject_reason,
  sum(_sample_interval * double3) AS rejected_sessions
FROM fibs_proxy_events
WHERE blob1 = 'session_reject'
GROUP BY reject_reason
ORDER BY rejected_sessions DESC
```

TCP connect failure rate:

```sql
SELECT
  hour,
  attempts,
  failures,
  failures / attempts AS failure_rate
FROM (
  SELECT
    toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
    sumIf(_sample_interval * double2, blob1 = 'session_start') AS attempts,
    sumIf(_sample_interval * double12, blob1 = 'tcp_connect_failed') AS failures
  FROM fibs_proxy_events
  WHERE blob1 IN ('session_start', 'tcp_connect_failed')
  GROUP BY hour
)
ORDER BY hour DESC
```

TCP connect latency:

```sql
SELECT
  quantileExactWeighted(0.5)(double4, _sample_interval) AS p50_ms,
  quantileExactWeighted(0.95)(double4, _sample_interval) AS p95_ms
FROM fibs_proxy_events
WHERE blob1 = 'tcp_connected'
```

Time to first FIBS byte:

```sql
SELECT
  quantileExactWeighted(0.5)(double5, _sample_interval) AS p50_ms,
  quantileExactWeighted(0.95)(double5, _sample_interval) AS p95_ms
FROM fibs_proxy_events
WHERE blob1 = 'session_close' AND double5 > 0
```

Session duration:

```sql
SELECT
  quantileExactWeighted(0.5)(double6, _sample_interval) AS p50_ms,
  quantileExactWeighted(0.95)(double6, _sample_interval) AS p95_ms
FROM fibs_proxy_events
WHERE blob1 = 'session_close'
```

Bytes by direction:

```sql
SELECT
  sum(_sample_interval * double9) AS browser_to_fibs_bytes,
  sum(_sample_interval * double10) AS fibs_to_browser_bytes
FROM fibs_proxy_events
WHERE blob1 = 'session_close'
```

Close reasons:

```sql
SELECT
  blob7 AS close_side,
  blob8 AS close_reason,
  sum(_sample_interval * double11) AS closes
FROM fibs_proxy_events
WHERE blob1 = 'session_close'
GROUP BY close_side, close_reason
ORDER BY closes DESC
```

Timeout rate:

```sql
SELECT
  hour,
  idle_timeouts,
  closes,
  idle_timeouts / closes AS timeout_rate
FROM (
  SELECT
    toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
    sum(_sample_interval * double13) AS idle_timeouts,
    sum(_sample_interval * double11) AS closes
  FROM fibs_proxy_events
  WHERE blob1 = 'session_close'
  GROUP BY hour
)
ORDER BY hour DESC
```

Error rate:

```sql
SELECT
  hour,
  errors,
  closes,
  errors / closes AS error_rate
FROM (
  SELECT
    toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
    sum(_sample_interval * double12) AS errors,
    sum(_sample_interval * double11) AS closes
  FROM fibs_proxy_events
  WHERE blob1 = 'session_close'
  GROUP BY hour
)
ORDER BY hour DESC
```

Usage by Cloudflare location:

```sql
SELECT
  blob9 AS colo,
  blob10 AS country,
  sum(_sample_interval * double2) AS sessions
FROM fibs_proxy_events
WHERE blob1 = 'bridge_request'
GROUP BY colo, country
ORDER BY sessions DESC
```

Historical concurrency proxy:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL '1' HOUR) AS hour,
  sumIf(_sample_interval * double2, blob1 = 'session_start') AS starts,
  sumIf(_sample_interval * double11, blob1 = 'session_close') AS closes
FROM fibs_proxy_events
WHERE blob1 IN ('session_start', 'session_close')
GROUP BY hour
ORDER BY hour DESC
```

Exact daily peak live concurrency requires shared live state and is not part of
the first Worker implementation.

Free-tier pressure:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL '1' DAY) AS day,
  sum(_sample_interval * double1) AS worker_requests,
  sum(_sample_interval * double2) AS accepted_sessions,
  sum(_sample_interval * double3) AS rejected_sessions
FROM fibs_proxy_events
WHERE blob1 = 'bridge_request'
GROUP BY day
ORDER BY day DESC
```
