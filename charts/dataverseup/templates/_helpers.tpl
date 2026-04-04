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
ConfigMap for compose-style bootstrap: bootstrap-chain.sh, apply-branding.sh, seed-content.sh, branding.env, seed fixtures.
*/}}
{{- define "dataverseup.bootstrapChainConfigMapName" -}}
{{- printf "%s-bootstrap-chain" (include "dataverseup.fullname" .) }}
{{- end }}

{{/*
Volume mounts for compose-mode bootstrap Jobs (configbaker runs bootstrap-chain.sh from the chain ConfigMap).
*/}}
{{- define "dataverseup.bootstrapComposeVolumeMounts" -}}
- name: bootstrap-scripts
  mountPath: /bootstrap-chain
  readOnly: true
- name: bootstrap-work
  mountPath: /work
- name: branding-env
  mountPath: /config
  readOnly: true
- name: seed-flat
  mountPath: /seed-flat
  readOnly: true
{{- end }}

{{/*
Volumes for compose-mode bootstrap (chain ConfigMap + emptyDir workdir).
*/}}
{{- define "dataverseup.bootstrapComposeVolumes" -}}
- name: bootstrap-scripts
  configMap:
    name: {{ include "dataverseup.bootstrapChainConfigMapName" . }}
    defaultMode: 0555
    items:
      - key: bootstrap-chain.sh
        path: bootstrap-chain.sh
      - key: apply-branding.sh
        path: apply-branding.sh
      - key: seed-content.sh
        path: seed-content.sh
- name: branding-env
  configMap:
    name: {{ include "dataverseup.bootstrapChainConfigMapName" . }}
    items:
      - key: branding.env
        path: branding.env
- name: seed-flat
  configMap:
    name: {{ include "dataverseup.bootstrapChainConfigMapName" . }}
    items:
      - key: demo-collection.json
        path: demo-collection.json
      - key: dataset-images.json
        path: dataset-images.json
      - key: dataset-tabular.json
        path: dataset-tabular.json
      - key: files_1x1.png
        path: files_1x1.png
      - key: files_badge.svg
        path: files_badge.svg
      - key: files_readme.txt
        path: files_readme.txt
      - key: files_sample.csv
        path: files_sample.csv
- name: bootstrap-work
  emptyDir: {}
{{- end }}

{{/*
Minimal env for default bootstrap Job (DATAVERSE_URL + TIMEOUT). Dict keys: dvUrl, timeout.
*/}}
{{- define "dataverseup.bootstrapJobMinimalEnv" -}}
- name: DATAVERSE_URL
  value: {{ index . "dvUrl" | quote }}
- name: TIMEOUT
  value: {{ index . "timeout" | quote }}
{{- end -}}

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
