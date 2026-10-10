{{/*
Reusable named templates ("helpers") for the platform-app chart.
Defined once here, pulled into every manifest with `include` so names, labels,
and selectors can never drift apart.
*/}}

{{/* Chart name, overridable via nameOverride. */}}
{{- define "platform-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name. Truncated to 63 chars for DNS/label limits.
Overridable via fullnameOverride.
*/}}
{{- define "platform-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Chart label value "name-version". */}}
{{- define "platform-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels — the STABLE subset used in selectors (must never change). */}}
{{- define "platform-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Full recommended label set for metadata.labels. */}}
{{- define "platform-app.labels" -}}
helm.sh/chart: {{ include "platform-app.chart" . }}
{{ include "platform-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: platform
{{- end -}}

{{/* Name of the ServiceAccount to use. */}}
{{- define "platform-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "platform-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
