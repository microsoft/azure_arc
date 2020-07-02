kubectl delete ns $env:ARC_DC_NAME

kubectl delete crd databases.mssqlcontroller.k8s.io
kubectl delete crd registrations.tina-instances.com

kubectl delete clusterrolebinding arcdatactrl:crb-mssql-metricsdc-reader
kubectl delete clusterrolebinding crb-arcdatactrl-controller
kubectl delete clusterrolebinding operator-rolebinding

kubectl delete clusterrole arcdatactrl:cr-mssql-metricsdc-reader
