$Env:ArcBoxLogsDir = "C:\ArcBox\Logs"

$certdns = "arcbox.devops.com"

Start-Transcript -Path $Env:ArcBoxLogsDir\ResetBookstore.log

############################
# - Deploy Ingress for Reset
############################

# Deploy Ingress for Bookbuyer Reset API 
echo "Deploying Ingress Resource for bookbuyer reset API"
$ingressBookbuyer = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookbuyer
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "$certdns"
    secretName: ingress-tls-csi
  rules:
  - host: "$certdns"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookbuyer
            port:
              number: 14001
        path: /bookbuyer/reset
"@
$ingressBookbuyer | kubectl apply -n bookbuyer -f -


# Deploy Ingress for Bookstore Reset API 
echo "Deploying Ingress Resource for bookstore reset API"
$ingressBookstore = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookstore
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "$certdns"
    secretName: ingress-tls-csi
  rules:
  - host: "$certdns"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore
            port:
              number: 14001
        path: /bookstore/reset
"@
$ingressBookstore | kubectl apply -n bookstore -f -

# Deploy Ingress for Bookstore-v2 Reset API 
echo "Deploying Ingress Resource for bookstore-v2 reset API"
$ingressBookstorev2 = @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookstore-v2
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "$certdns"
    secretName: ingress-tls-csi
  rules:
  - host: "$certdns"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore-v2
            port:
              number: 14001
        path: /bookstore-v2/reset
"@
$ingressBookstorev2 | kubectl apply -n bookstore -f -


####################
# - Invoke Reset API
####################

Invoke-WebRequest -Uri "https://$certdns/bookbuyer/reset" -UseBasicParsing
Invoke-WebRequest -Uri "https://$certdns/bookstore/reset" -UseBasicParsing
Invoke-WebRequest -Uri "https://$certdns/bookstore-v2/reset" -UseBasicParsing
