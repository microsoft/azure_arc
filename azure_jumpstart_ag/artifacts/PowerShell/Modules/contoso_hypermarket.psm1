function Get-K3sConfigFile{
  # Downloading k3s Kubernetes cluster kubeconfig file
  Write-Host "Downloading k3s Kubeconfigs"
  $Env:AZCOPY_AUTO_LOGIN_TYPE="PSCRED"
  $Env:KUBECONFIG=""
  foreach ($cluster in $AgConfig.SiteConfig.GetEnumerator()) {
    $clusterName = $cluster.Name.ToLower()
    $arcClusterName = $AgConfig.SiteConfig[$clusterName].ArcClusterName + "-$namingGuid"
    $containerName = $arcClusterName.toLower()
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/config"
    azcopy copy $sourceFile "C:\Users\$adminUsername\.kube\ag-k3s-$clusterName" --check-length=false
    $sourceFile = "https://$stagingStorageAccountName.blob.core.windows.net/$containerName/*"
    azcopy cp --check-md5 FailIfDifferentOrMissing $sourceFile  "$AgLogsDir\" --include-pattern "*.log"
  }
}

function Configure-K3sClusters {
  Write-Host "Configuring kube-vip on K3s clusterS"
  $clusters = $AgConfig.SiteConfig.GetEnumerator()
  foreach ($cluster in $clusters) {
      if ($cluster.Value.Type -eq "k3s") {
          $clusterName = $cluster.Name.ToLower()
          $vmName = $cluster.Value.ArcClusterName+"-$namingGuid"
          $Env:KUBECONFIG="C:\Users\$adminUsername\.kube\ag-k3s-$clusterName"
          kubectx
          $k3sVIP = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``true``].privateIPAddress" -otsv
          Write-Host "Assigning kube-vip-role on k3s cluster"
$kubeVipRBAC = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-vip
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  name: system:kube-vip-role
rules:
  - apiGroups: [""]
    resources: ["services/status"]
    verbs: ["update"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["list","get","watch", "update"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["list","get","watch", "update", "patch"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["list", "get", "watch", "update", "create"]
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["list","get","watch", "update"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system:kube-vip-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-vip-role
subjects:
- kind: ServiceAccount
  name: kube-vip
  namespace: kube-system
"@

$kubeVipRBAC | kubectl apply -f -

$kubeVipDaemonset = @"
apiVersion: apps/v1
kind: DaemonSet
metadata:
  creationTimestamp: null
  labels:
    app.kubernetes.io/name: kube-vip-ds
    app.kubernetes.io/version: v0.7.0
  name: kube-vip-ds
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-vip-ds
  template:
    metadata:
      creationTimestamp: null
      labels:
        app.kubernetes.io/name: kube-vip-ds
        app.kubernetes.io/version: v0.7.0
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: Exists
            - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
      containers:
      - args:
        - manager
        env:
        - name: vip_arp
          value: "true"
        - name: port
          value: "6443"
        - name: vip_interface
          value: eth0
        - name: vip_cidr
          value: "32"
        - name: dns_mode
          value: first
        - name: cp_enable
          value: "true"
        - name: cp_namespace
          value: kube-system
        - name: svc_enable
          value: "true"
        - name: svc_leasename
          value: plndr-svcs-lock
        - name: vip_leaderelection
          value: "true"
        - name: vip_leasename
          value: plndr-cp-lock
        - name: vip_leaseduration
          value: "5"
        - name: vip_renewdeadline
          value: "3"
        - name: vip_retryperiod
          value: "1"
        - name: address
          value: "$k3sVIP"
        - name: prometheus_server
          value: :2112
        image: ghcr.io/kube-vip/kube-vip:v0.7.0
        imagePullPolicy: Always
        name: kube-vip
        resources: {}
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
      hostNetwork: true
      serviceAccountName: kube-vip
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists
  updateStrategy: {}
status:
  currentNumberScheduled: 0
  desiredNumberScheduled: 0
  numberMisscheduled: 0
  numberReady: 0
"@

          $kubeVipDaemonset | kubectl apply -f -

          Write-Host "Deploying Kube vip cloud controller on k3s cluster"
          kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

          $serviceIpRange = az network nic ip-config list --resource-group $Env:resourceGroup --nic-name $vmName-NIC --query "[?primary == ``false``].privateIPAddress" -otsv
          $sortedIps = $serviceIpRange | Sort-Object {[System.Version]$_}
          $lowestServiceIp = $sortedIps[0]
          $highestServiceIp = $sortedIps[-1]

          kubectl create configmap -n kube-system kubevip --from-literal range-global=$lowestServiceIp-$highestServiceIp
          Start-Sleep -Seconds 30

          Write-Host "Creating longhorn storage on K3scluster"
          kubectl apply -f "$AgToolsDir\longhorn.yaml"
          Start-Sleep -Seconds 30
          Write-Host "`n"
          }
      }

}