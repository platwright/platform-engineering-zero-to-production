// platform-overview.jsonnet -- the Platform Overview Dashboard, as code.
//
// This Grafonnet source GENERATES platform-overview.json. In a real repo you render
// it in CI and let a Grafana sidecar apply the result:
//
//   jb init
//   jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main
//   jsonnet -J vendor platform-overview.jsonnet > platform-overview.json
//
// Why bother? Panels become reusable FUNCTIONS (see tsPanel/target below), the board
// is diffable and reviewable, and one templated file replaces dozens of copies.
// Targets grafonnet-latest.

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local timeSeries = g.panel.timeSeries;
local stat = g.panel.stat;
local table = g.panel.table;
local prometheus = g.query.prometheus;
local varQuery = g.dashboard.variable.query;
local varDatasource = g.dashboard.variable.datasource;

// Every panel and query reads the board's $datasource variable, so one dashboard
// works across clusters without edits.
local ds = '${datasource}';
local promDs = { type: 'prometheus', uid: ds };

// --- reusable helpers (the whole point of dashboards as code) ---------------

local target(expr, legend='') =
  prometheus.new(ds, expr)
  + (if legend != '' then prometheus.withLegendFormat(legend) else {});

local tsPanel(title, unit, description, targets, gridPos) =
  timeSeries.new(title)
  + timeSeries.panelOptions.withDescription(description)
  + timeSeries.standardOptions.withUnit(unit)
  + timeSeries.queryOptions.withTargets(targets)
  + { datasource: promDs, gridPos: gridPos };

local tablePanel(title, description, expr, gridPos) =
  table.new(title)
  + table.panelOptions.withDescription(description)
  + table.queryOptions.withTargets([
      target(expr) + { format: 'table', instant: true },
    ])
  + { datasource: promDs, gridPos: gridPos };

// --- template variables -----------------------------------------------------

local variables = [
  varDatasource.new('datasource', 'prometheus')
  + varDatasource.generalOptions.withLabel('Data source'),

  varQuery.new('namespace', 'label_values(kube_pod_info, namespace)')
  + varQuery.generalOptions.withLabel('Namespace')
  + varQuery.selectionOptions.withIncludeAll(true)
  + varQuery.selectionOptions.withMulti(true)
  + { datasource: promDs },

  varQuery.new('service', 'label_values(http_requests_total, job)')
  + varQuery.generalOptions.withLabel('Service (job)')
  + varQuery.selectionOptions.withIncludeAll(true)
  + varQuery.selectionOptions.withMulti(true)
  + { datasource: promDs },
];

// --- panels: top-down (summary first, drill-down below) ---------------------

local panels = [
  tsPanel(
    'CPU usage by namespace (cores)',
    'short',
    'USE: where is compute being spent across tenants?',
    [target('sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))', '{{namespace}}')],
    { h: 8, w: 12, x: 0, y: 0 },
  ),
  tsPanel(
    'Memory working set by namespace (bytes)',
    'bytes',
    'USE: memory pressure per tenant.',
    [target('sum by (namespace) (container_memory_working_set_bytes)', '{{namespace}}')],
    { h: 8, w: 12, x: 12, y: 0 },
  ),
  tsPanel(
    'Request & error rate per service',
    'reqps',
    'RED: traffic and failures for the selected service(s).',
    [
      target('sum by (job) (rate(http_requests_total{job=~"$service"}[5m]))', '{{job}} total'),
      target('sum by (job) (rate(http_requests_total{job=~"$service", code=~"4..|5.."}[5m]))', '{{job}} errors'),
    ],
    { h: 8, w: 12, x: 0, y: 8 },
  ),
  tsPanel(
    'Latency p50 / p95 / p99 (seconds)',
    's',
    'RED: tail latency for the selected service(s).',
    [
      target('histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$service"}[5m])))', 'p50'),
      target('histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$service"}[5m])))', 'p95'),
      target('histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{job=~"$service"}[5m])))', 'p99'),
    ],
    { h: 8, w: 12, x: 12, y: 8 },
  ),
  stat.new('SLO burn rate (99.9% target)')
  + stat.panelOptions.withDescription('Error ratio / error budget (1 - SLO). >1 burns budget too fast. Formalized in Module 11.7.')
  + stat.standardOptions.withUnit('none')
  + stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'orange', value: 1 },
      { color: 'red', value: 14.4 },
    ])
  + stat.queryOptions.withTargets([
      target('(sum(rate(http_requests_total{code=~"4..|5.."}[5m])) / sum(rate(http_requests_total[5m]))) / (1 - 0.999)'),
    ])
  + { datasource: promDs, gridPos: { h: 8, w: 6, x: 0, y: 16 } },

  tablePanel(
    'Active incidents (firing alerts)',
    'Symptom-level: what is on fire right now.',
    'ALERTS{alertstate="firing"}',
    { h: 8, w: 18, x: 6, y: 16 },
  ),
  tablePanel(
    'Rollout activity by deployment (ArgoCD sync events in Project 3)',
    'Proxy for recent deployments via kube-state-metrics; wire argocd_app_sync_total in Project 3.',
    'sum by (namespace, deployment) (kube_deployment_status_replicas_available)',
    { h: 8, w: 24, x: 0, y: 24 },
  ),
];

// --- the dashboard ----------------------------------------------------------

dashboard.new('Platform Overview')
+ dashboard.withUid('platform-overview')
+ dashboard.withTags(['platform', 'observability', 'overview'])
+ dashboard.withRefresh('30s')
+ dashboard.time.withFrom('now-1h')
+ dashboard.time.withTo('now')
+ dashboard.withVariables(variables)
+ dashboard.withPanels(panels)
