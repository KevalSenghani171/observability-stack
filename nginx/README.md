helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443


helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
  
  
nano letsencrypt-prod.yaml

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: YOUR-EMAIL@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
					
			
kubectl apply -f letsencrypt-prod.yaml

sudo apt update
sudo apt install nginx -y

sudo nano /etc/nginx/sites-available/grafana


server {
    listen 80;
    server_name {CUSTOM-DNS-NAME};

    location / {
        proxy_pass http://{MASTER-NODE-PRIVATE-IP}:30080;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

Run Below commands in that node where nginx-ingress pod is present:

sudo nginx -t
sudo systemctl reload nginx


sudo apt update
sudo apt install libnginx-mod-stream -y

sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

sudo nano /etc/nginx/nginx.conf

Add the following stream block between the events and http blocks:
stream {
    server {
        listen 443;
        proxy_pass {MASTER-NODE-PRIVATE-IP}:30443;
        proxy_connect_timeout 10s;
        proxy_timeout 300s;
    }
}

Also if you have multiple dns entries add below line inside http section

      server {
        listen 80;
        server_name grafana-keval.duckdns.org prometheus-keval.duckdns.org;

        location / {
            proxy_pass http://172.31.46.165:30080;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

sudo nginx -t
sudo systemctl reload nginx

E.g Prometheus DNS in prometheus helm chart

  ingress:
    enabled: true
    ingressClassName: nginx

    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "300"

    hosts:
      - prometheus-keval.duckdns.org

    path: /
    pathType: Prefix

    tls:
      - secretName: prometheus-tls
        hosts:
          - prometheus-keval.duckdns.org