helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts

helm repo update

helm upgrade --install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -f values.yaml \
  --namespace kube-system \
  --set syncSecret.enabled=true

helm repo add aws-secrets-manager \
  https://aws.github.io/secrets-store-csi-driver-provider-aws

helm repo update
 
helm upgrade --install secrets-provider-aws \
  aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  -f values.yaml \
  --namespace kube-system
  
only try if above fails
helm upgrade --install secrets-provider-aws \
  aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  -f values.yaml \
  --namespace kube-system \
  --set secrets-store-csi-driver.install=false
  
  
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -f values.yaml \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true \
  --wait
  

Create one custom policy in AWS IAM with below properties and attach that policy with role that are attached to all kubernetes nodes.

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:ap-south-1:{AWS-ACCOUNT}:secret:{SECRET-NAME}*"
        }
    ]
}

kubectl apply -f grafana-secretstore.yaml -n devops-tools


kubectl apply -f grafana-externalsecret.yaml -n devops-tools


kubectl apply -f grafana-secret-provider.yaml -n devops-tools