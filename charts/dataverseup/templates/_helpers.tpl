{{/*
Expand the name of the chart.
*/}}
{{- define "dataverseup.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dataverseup.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dataverseup.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dataverseup.labels" -}}
helm.sh/chart: {{ include "dataverseup.chart" . }}
{{ include "dataverseup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dataverseup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dataverseup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Bootstrap / configbaker Job pod labels. Must NOT use selectorLabels alone: Deployment matchLabels are only
name+instance, so Job pods would match and `kubectl logs deploy/<release>` can pick the wrong pod.
*/}}
{{- define "dataverseup.bootstrapPodLabels" -}}
helm.sh/chart: {{ include "dataverseup.chart" . }}
app.kubernetes.io/name: {{ include "dataverseup.name" . }}-bootstrap
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Service / CLI label query for the main Dataverse pods only. Pods also set component=primary;
Deployment matchLabels stay name+instance only so upgrades do not hit immutable selector changes.
*/}}
{{- define "dataverseup.primarySelectorLabels" -}}
{{ include "dataverseup.selectorLabels" . }}
app.kubernetes.io/component: primary
{{- end }}

{{/*
Labels for the optional in-chart standalone Solr Deployment/Service (must NOT match dataverseup.selectorLabels
or the main Deployment ReplicaSet will count Solr pods).
*/}}
{{- define "dataverseup.internalSolrLabels" -}}
helm.sh/chart: {{ include "dataverseup.chart" . }}
app.kubernetes.io/name: {{ include "dataverseup.name" . }}-solr
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: internal-solr
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dataverseup.internalSolrSelectorLabels" -}}
app.kubernetes.io/name: {{ include "dataverseup.name" . }}-solr
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: internal-solr
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dataverseup.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dataverseup.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Solr admin base URL (no path) for solrInit initContainer: explicit solrInit.solrHttpBase, else in-release Solr
Service when internalSolr is enabled, else a placeholder for external / shared cluster Solr (override required).
*/}}
{{- define "dataverseup.solrHttpBase" -}}
{{- if .Values.solrInit.solrHttpBase -}}
{{- .Values.solrInit.solrHttpBase -}}
{{- else if .Values.internalSolr.enabled -}}
http://{{ include "dataverseup.fullname" . }}-solr.{{ .Release.Namespace }}.svc.cluster.local:8983
{{- else -}}
http://solr.solr.svc.cluster.local:8983
{{- end -}}
{{- end }}
