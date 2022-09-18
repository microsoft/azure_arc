{{- /*
Defines a single line of template that the variable can be shared for multiple yaml files.
The template renders as: "arc-webhook-job-xxxxx", where xxxxx is the first 5 characters of the checksum of the image tag.
*/}}

{{- define "webhookjob.name" }} {{- $webhookJobSuffix := print .Values.systemDefaultValues.image | sha256sum }} arc-webhook-job-{{ substr 0 5 $webhookJobSuffix }} {{ end }}