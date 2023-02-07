kubectl create serviceaccount jumpstart-user

kubectl create clusterrolebinding jumpstart-user-binding --clusterrole cluster-admin --serviceaccount default:jumpstart-user

kubectl apply -f jumpstart-user-secret.yaml

$TOKEN = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret jumpstart-user-secret -o jsonpath='{$.data.token}'))))

Write-Console $TOKEN