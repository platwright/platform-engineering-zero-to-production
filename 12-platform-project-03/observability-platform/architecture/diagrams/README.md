# Diagrams

Put exported diagrams for this project here (SVG preferred). The authoritative
description lives in [../architecture.md](../architecture.md); add diagram-as-code
sources alongside any exported images.

Suggested diagrams:

- Telemetry flow: app (OTel SDK) → agent → gateway (tail sampling) → LGTM → Grafana.
- The three pillars correlated (metric exemplar → trace → logs).
- SLO/error-budget burn-rate (fast vs slow burn windows).
