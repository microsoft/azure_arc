{{- /*
Defines service account variables
*/}}

{{- define "installerServiceAccount" }}{{ regexReplaceAll "^system:serviceaccount:.*:" (.Values.Azure.LeastPrivilegeSettings.InstallerServiceAccount | default .Values.systemDefaultValues.installerServiceAccount | default "") "" }}{{ end }}

{{- define "runtimeServiceAccount" }}{{ regexReplaceAll "^system:serviceaccount:.*:" (.Values.Azure.LeastPrivilegeSettings.RuntimeServiceAccount | default .Values.systemDefaultValues.runtimeServiceAccount | default "sa-arc-bootstrapper") "" }}{{ end }}