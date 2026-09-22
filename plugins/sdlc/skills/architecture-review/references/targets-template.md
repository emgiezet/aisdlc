## Non-functional targets

- **Availability tier:** <99.5 | 99.9 | 99.95 | 99.99 | 99.999> %
- **Traffic:** avg <n> rps · peak <n> rps (×<peak/avg>) · concurrency <n> · p95 payload <size>
- **Growth:** +<size>/month · retention <duration>
- **RPO / RTO:** <duration> / <duration>
- **Hard dependencies:** <name> (<availability>, <topology or vendor SLA + page>) · …
- **Soft dependencies:** <name> (<how the request degrades>) · …
- **Load test:** <n> rps sustained <duration> on <date> — <pass | fail | not run>
- **Failover rehearsal:** <date>, RTO measured <duration> — or `not rehearsed`
- **Backup restore rehearsal:** <date> — or `not rehearsed`

<!-- Every value is a number, a date, or a named dependency. An adjective here is a finding. -->
