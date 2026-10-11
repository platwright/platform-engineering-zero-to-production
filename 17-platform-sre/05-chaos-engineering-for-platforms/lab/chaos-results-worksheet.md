<!-- markdownlint-disable MD033 -->
# Chaos results worksheet

> For each experiment: state the steady-state hypothesis, run it, and judge the result
> on three layers — **system** (did the SLO hold?), **signals** (did the right alert
> fire?), and **humans** (did the runbook/response work?). Replace every `<...>`.

## Experiment 1 — kill a third of Argo CD pods

- **Steady state (before):** `<e.g. guestbook Synced/Healthy; API answering>`
- **Hypothesis:** app-sync success stays `>= 99%` and the API stays responsive while a
  third of pods are killed.
- **Result:** `<held / broke>`
- **System:** `<did the app stay Synced/Healthy? recovery time?>`
- **Signals:** `<did a burn-rate alert fire or stay quiet appropriately?>`
- **Humans:** `<was intervention/a runbook needed, or did it self-heal?>`
- **Weakness found + follow-up action:** `<none / describe + owner>`

## Experiment 2 — 500ms latency to Prometheus

- **Steady state (before):** `<dashboards load; alert rules evaluate>`
- **Hypothesis:** dashboards degrade gracefully (slower / timeout warnings) and alert
  evaluation still fires — a slow monitoring stack is not a blind one.
- **Result:** `<held / broke>`
- **System:** `<graceful degradation or total blackout?>`
- **Signals:** `<did alerts still fire? any query-timeout alert?>`
- **Humans:** `<could you still observe the platform during the fault?>`
- **Weakness found + follow-up action:** `<none / describe + owner>`

## Experiment 3 — delete the ESO pod

- **Steady state (before):** `<ExternalSecrets synced; managed Secrets exist>`
- **Hypothesis:** existing secrets survive; ESO restarts within ~30s and catches up on
  missed refreshes.
- **Result:** `<held / broke>`
- **System:** `<did existing Secrets persist? restart time?>`
- **Signals:** `<did an alert fire for the missing controller?>`
- **Humans:** `<any manual action needed to recover?>`
- **Weakness found + follow-up action:** `<none / describe + owner>`

## GameDay summary

- **Overall confidence gained:** `<low / medium / high — in what, specifically>`
- **Top weakness to fix first:** `<item + owner + due date>`
- **Experiments to automate as regression tests:** `<which ones>`
- **Next failure modes to try:** `<node failure, network partition, storage, ...>`
