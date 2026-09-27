# Grafana + HashiCorp Vault + Kubernetes Authentication

This guide configures HashiCorp Vault to securely provide MySQL database credentials to Grafana using the Vault Agent Injector and Kubernetes authentication.

## Architecture

```text
Kubernetes
│
├── Grafana Pod
│   ├── Grafana Container
│   │   └── Reads /vault/secrets/mysql-secret
│   │
│   └── Vault Agent Injector
│       └── Authenticates using Kubernetes ServiceAccount
│
├── Vault
│   ├── Kubernetes Auth
│   ├── Policy: grafana-read
│   ├── Role: vault-role
│   └── Secret: secret/mysql-secret
│
└── MySQL / RDS
    └── Grafana Database
```

---

# 1. Prerequisites

The following must already be available:

- Kubernetes cluster
- `kubectl`
- HashiCorp Vault
- Grafana
- MySQL / RDS database
- Grafana ServiceAccount named:

```text
vault-serviceaccount
```

The examples in this guide use:

```text
Namespace: devops-tools
Vault Pod: vault-0
Vault Service: vault
Grafana ServiceAccount: vault-serviceaccount
Vault Role: vault-role
Vault Policy: grafana-read
Secret Path: secret/mysql-secret
```

---

# 2. Access the Vault Pod

Enter the Vault pod:

```bash
kubectl exec -it -n devops-tools vault-0 -- sh
```

Check Vault status:

```bash
vault status
```

---

# 3. Store MySQL Credentials in Vault

Create the Grafana MySQL secret:

```bash
vault kv put secret/mysql-secret \
  username="USER" \
  password="PASSWORD" \
  host="MYSQL-HOST" \
  port="3306" \
  database="grafana"
```

> Replace `USER`, `PASSWORD`, `MYSQL-HOST`, and `grafana` with your actual database values.

Verify the secret:

```bash
vault kv get secret/mysql-secret
```

The secret should contain values similar to:

```text
username    USER
password    PASSWORD
host        MYSQL-HOST
port        3306
database    grafana
```

---

# 4. Create the Grafana Vault Policy

Create the policy file:

```bash
cat > /tmp/grafana-read-policy.hcl <<'EOF'
path "secret/data/mysql-secret" {
  capabilities = ["read"]
}
EOF
```

Write the policy to Vault:

```bash
vault policy write grafana-read /tmp/grafana-read-policy.hcl
```

Verify the policy:

```bash
vault policy read grafana-read
```

Expected output:

```text
path "secret/data/mysql-secret" {
  capabilities = ["read"]
}
```

The policy allows Grafana's Vault role to read only:

```text
secret/data/mysql-secret
```

---

# 5. Enable Kubernetes Authentication

Check currently enabled Vault authentication methods:

```bash
vault auth list
```

Enable Kubernetes authentication:

```bash
vault auth enable kubernetes
```

If Kubernetes authentication is already enabled, Vault will report that the path already exists. In that case, continue with the configuration step.

---

# 6. Find the Vault ServiceAccount

Check which ServiceAccount is used by the Vault pod:

```bash
kubectl get pod vault-0 -n devops-tools \
  -o jsonpath='{.spec.serviceAccountName}'; echo
```

For example:

```text
vault
```

Save the ServiceAccount name if it is different from `vault`.

---

# 7. Create a Token for Vault Kubernetes Authentication

Create a Kubernetes token for the Vault ServiceAccount:

```bash
VAULT_SA=$(kubectl get pod vault-0 -n devops-tools \
  -o jsonpath='{.spec.serviceAccountName}')

VAULT_TOKEN=$(kubectl create token "$VAULT_SA" -n devops-tools)
```

Verify that the token exists:

```bash
test -n "$VAULT_TOKEN" && echo "VAULT_TOKEN is set"
```

---

# 8. Configure Vault Kubernetes Authentication

Run this from inside the Vault pod:

```bash
vault write auth/kubernetes/config \
  token_reviewer_jwt="$VAULT_TOKEN" \
  kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

Vault will now use Kubernetes TokenReview to authenticate Grafana pods.

---

# 9. Allow Vault to Review Kubernetes Tokens

Create the required ClusterRoleBinding:

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault
    namespace: devops-tools
EOF
```

### Important

If the Vault pod's ServiceAccount from the previous step is **not** named `vault`, change:

```yaml
name: vault
```

to the actual ServiceAccount name.

For example:

```yaml
subjects:
  - kind: ServiceAccount
    name: <VAULT_SERVICE_ACCOUNT>
    namespace: devops-tools
```

---

# 10. Verify TokenReview Permissions

Run:

```bash
kubectl auth can-i create tokenreviews \
  --as=system:serviceaccount:devops-tools:vault
```

Expected:

```text
yes
```

If your Vault ServiceAccount has a different name, replace `vault` accordingly.

---

# 11. Create the Vault Kubernetes Role

Create the Vault role used by Grafana:

```bash
vault write auth/kubernetes/role/vault-role \
  bound_service_account_names=vault-serviceaccount \
  bound_service_account_namespaces=devops-tools \
  policies=grafana-read \
  ttl=1h
```

Verify the role:

```bash
vault read auth/kubernetes/role/vault-role
```

The role should contain:

```text
bound_service_account_names:
    vault-serviceaccount

bound_service_account_namespaces:
    devops-tools

policies:
    grafana-read
```

---

# 12. Grafana Helm Configuration

Add the following configuration to your Grafana `values.yaml`.

## Vault Configuration

```yaml
vault:
  enabled: true

  annotations:
    vault.hashicorp.com/agent-inject: "true"

    vault.hashicorp.com/role: "vault-role"

    vault.hashicorp.com/service: "http://vault.devops-tools.svc:8200"

    vault.hashicorp.com/agent-inject-secret-mysql-secret: "secret/data/mysql-secret"

    vault.hashicorp.com/agent-inject-template-mysql-secret: |
      {{- with secret "secret/data/mysql-secret" }}
      export GF_DATABASE_TYPE="mysql"
      export GF_DATABASE_HOST="{{ .Data.data.host }}"
      export GF_DATABASE_PORT="{{ .Data.data.port }}"
      export GF_DATABASE_NAME="{{ .Data.data.database }}"
      export GF_DATABASE_USER="{{ .Data.data.username }}"
      export GF_DATABASE_PASSWORD="{{ .Data.data.password }}"
      {{- end }}
```

---

# 13. Grafana Administrator Credentials

For a new Grafana database, the administrator credentials can be configured as follows:

```yaml
adminUser: admin
adminPassword: Admin123

admin:
  existingSecret: ""
  userKey: admin-user
  passwordKey: admin-password
```

> `adminPassword` is normally used when Grafana creates the admin account for the first time. Changing this value does not necessarily overwrite an existing admin password in an already initialized Grafana database.

---

# 14. Grafana Container Startup Command

The Grafana container must source the Vault-generated secret before starting Grafana.

Use:

```yaml
command:
  - sh
  - -c
  - |
    . /vault/secrets/mysql-secret
    exec /run.sh
```

This causes Grafana to receive:

```text
GF_DATABASE_TYPE
GF_DATABASE_HOST
GF_DATABASE_PORT
GF_DATABASE_NAME
GF_DATABASE_USER
GF_DATABASE_PASSWORD
```

from Vault.

---

# 15. Important: Pod Annotations

The Vault annotations must be applied to the **Grafana Pod template**.

They need to ultimately appear under:

```yaml
spec:
  template:
    metadata:
      annotations:
```

For example:

```yaml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "vault-role"
        vault.hashicorp.com/service: "http://vault.devops-tools.svc:8200"
        vault.hashicorp.com/agent-inject-secret-mysql-secret: "secret/data/mysql-secret"
        vault.hashicorp.com/agent-inject-template-mysql-secret: |
          {{- with secret "secret/data/mysql-secret" }}
          export GF_DATABASE_TYPE="mysql"
          export GF_DATABASE_HOST="{{ .Data.data.host }}"
          export GF_DATABASE_PORT="{{ .Data.data.port }}"
          export GF_DATABASE_NAME="{{ .Data.data.database }}"
          export GF_DATABASE_USER="{{ .Data.data.username }}"
          export GF_DATABASE_PASSWORD="{{ .Data.data.password }}"
          {{- end }}
```

---

# 16. Deploy Grafana

After updating `values.yaml`, upgrade the Helm release:

```bash
helm upgrade grafana <YOUR_CHART> \
  -n devops-tools \
  -f values.yaml
```

Check the Grafana pod:

```bash
kubectl get pods -n devops-tools | grep grafana
```

---

# 17. Verify Vault Injection

Check the Grafana pod containers:

```bash
kubectl get pod <GRAFANA_POD> -n devops-tools \
  -o jsonpath='{.spec.containers[*].name}'; echo
```

You should see both Grafana and the Vault Agent container.

Check the generated secret file:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  ls -l /vault/secrets/
```

Expected:

```text
mysql-secret
```

---

# 18. Verify Database Environment

Do not print the database password.

Run:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- sh -c '
echo "GF_DATABASE_TYPE=$GF_DATABASE_TYPE"
echo "GF_DATABASE_HOST=$GF_DATABASE_HOST"
echo "GF_DATABASE_PORT=$GF_DATABASE_PORT"
echo "GF_DATABASE_NAME=$GF_DATABASE_NAME"
echo "GF_DATABASE_USER=$GF_DATABASE_USER"
test -n "$GF_DATABASE_PASSWORD" && echo "GF_DATABASE_PASSWORD is SET"
'
```

Expected:

```text
GF_DATABASE_TYPE=mysql
GF_DATABASE_HOST=MYSQL-HOST
GF_DATABASE_PORT=3306
GF_DATABASE_NAME=grafana
GF_DATABASE_USER=USER
GF_DATABASE_PASSWORD is SET
```

---

# 19. Verify Grafana Database Connection

Check Grafana logs:

```bash
kubectl logs -n devops-tools <GRAFANA_POD> -c grafana
```

Look for:

```text
Connecting to DB dbtype=mysql
```

Then:

```text
Starting DB migrations
```

And finally:

```text
migrations completed
```

If you see:

```text
dbtype=sqlite3
```

Grafana is not receiving the Vault database configuration.

---

# 20. Test Vault Authentication Manually

Create a token for the Grafana ServiceAccount:

```bash
JWT=$(kubectl create token vault-serviceaccount -n devops-tools)
```

Then authenticate against Vault:

```bash
vault write auth/kubernetes/login \
  role=vault-role \
  jwt="$JWT"
```

A successful response should contain:

```text
auth/
client_token
policies
```

The policy should include:

```text
grafana-read
```

---

# 21. Test Secret Access

Verify that the secret exists:

```bash
vault kv get secret/mysql-secret
```

The expected logical path is:

```text
secret/mysql-secret
```

For the KV v2 API, the policy path is:

```text
secret/data/mysql-secret
```

These are expected to be different.

---

# 22. Reset Grafana Admin Password

If Grafana is already initialized and the admin password needs to be reset, run the CLI **after sourcing the Vault database configuration**:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- sh -c '
. /vault/secrets/mysql-secret
grafana cli admin reset-admin-password "Admin123"
'
```

The output must show:

```text
Connecting to DB dbtype=mysql
```

and:

```text
Admin password changed successfully
```

If it shows:

```text
dbtype=sqlite3
```

the password is being changed in SQLite rather than the MySQL database.

After a successful reset:

```text
Username: admin
Password: Admin123
```

---

# 23. Troubleshooting

## Vault Agent authentication fails with 403

Check:

```bash
vault read auth/kubernetes/role/vault-role
```

Verify:

```text
bound_service_account_names = vault-serviceaccount
bound_service_account_namespaces = devops-tools
policies = grafana-read
```

Check the Grafana ServiceAccount:

```bash
kubectl get pod <GRAFANA_POD> -n devops-tools \
  -o jsonpath='{.spec.serviceAccountName}'; echo
```

It must be:

```text
vault-serviceaccount
```

---

## Vault returns "no secret exists"

Check:

```bash
vault kv get secret/mysql-secret
```

Verify the Vault Agent annotation uses:

```yaml
vault.hashicorp.com/agent-inject-secret-mysql-secret: "secret/data/mysql-secret"
```

And the template uses:

```text
secret "secret/data/mysql-secret"
```

---

## Grafana connects to SQLite instead of MySQL

Check:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  sh -c 'echo "$GF_DATABASE_TYPE"'
```

It should return:

```text
mysql
```

Make sure the startup command sources Vault before `/run.sh`:

```yaml
command:
  - sh
  - -c
  - |
    . /vault/secrets/mysql-secret
    exec /run.sh
```

---

## Grafana cannot connect to MySQL

Check:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  sh -c 'echo "$GF_DATABASE_HOST"; echo "$GF_DATABASE_PORT"; echo "$GF_DATABASE_NAME"; echo "$GF_DATABASE_USER"'
```

Verify DNS:

```bash
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  getent hosts "$GF_DATABASE_HOST"
```

Verify that the RDS/MySQL security group allows connections from the Kubernetes nodes/pods.

---

# 24. Grafana Database Migration Errors

If Grafana logs show an error such as:

```text
migration failed
id="add index dashboard.account_id"
Error 1072 (42000): Key column 'account_id' doesn't exist in table
```

this indicates that the existing MySQL Grafana schema does not match the schema expected by the installed Grafana version.

If the database is disposable, recreate it and allow Grafana to initialize it from scratch.

Example:

```sql
DROP DATABASE grafana_new;

CREATE DATABASE grafana_new;

GRANT ALL PRIVILEGES ON grafana_new.* 
TO 'grafana_user'@'%';

FLUSH PRIVILEGES;
```

Then update Vault:

```bash
vault kv patch secret/mysql-secret database="grafana_new"
```

Restart Grafana:

```bash
kubectl delete pod <GRAFANA_POD> -n devops-tools
```

Watch the logs:

```bash
kubectl logs -n devops-tools -f <GRAFANA_POD> -c grafana
```

Do **not** manually add missing Grafana columns or indexes unless you have verified the intended schema and migration history.

---

# 25. Dashboard Provisioning

If Grafana logs show:

```text
failed to search for dashboards
stat /var/lib/grafana/dashboards/OBS: no such file or directory
```

make sure the directory exists before Grafana starts.

For example:

```yaml
command:
  - sh
  - -c
  - |
    mkdir -p /var/lib/grafana/dashboards/OBS
    . /vault/secrets/mysql-secret
    exec /run.sh
```

Do not put commands after:

```bash
exec /run.sh
```

because `exec` replaces the current shell process and commands after it will not execute.

---

# 26. Complete Configuration Summary

### Vault Secret

```text
secret/mysql-secret
```

### Vault Policy

```text
grafana-read
```

### Vault Role

```text
vault-role
```

### Grafana ServiceAccount

```text
vault-serviceaccount
```

### Kubernetes Namespace

```text
devops-tools
```

### Vault Service

```text
vault.devops-tools.svc:8200
```

### Vault KV v2 Policy Path

```text
secret/data/mysql-secret
```

### Grafana Secret File

```text
/vault/secrets/mysql-secret
```

### Grafana Database

```text
MySQL / RDS
```

---

# 27. Security Notes

Do not commit real credentials to Git.

Do not put real passwords in:

```text
values.yaml
README.md
Helm charts
Kubernetes manifests
Git repositories
```

Vault should remain the source of truth for MySQL credentials.

For example, use:

```bash
vault kv put secret/mysql-secret \
  username="USER" \
  password="PASSWORD" \
  host="MYSQL-HOST" \
  database="grafana"
```

with the real values only in your Vault environment.

Avoid displaying passwords in terminal output or logs whenever possible.

---

# 28. Quick Verification Checklist

Run these checks in order:

```bash
# Vault
vault status

# Secret
vault kv get secret/mysql-secret

# Policy
vault policy read grafana-read

# Kubernetes auth
vault auth list

# Role
vault read auth/kubernetes/role/vault-role

# TokenReview
kubectl auth can-i create tokenreviews \
  --as=system:serviceaccount:devops-tools:vault

# Grafana ServiceAccount
kubectl get pod <GRAFANA_POD> -n devops-tools \
  -o jsonpath='{.spec.serviceAccountName}'; echo

# Vault secret file
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  ls -l /vault/secrets/

# Database type
kubectl exec -n devops-tools <GRAFANA_POD> -c grafana -- \
  sh -c 'echo "$GF_DATABASE_TYPE"'

# Grafana logs
kubectl logs -n devops-tools <GRAFANA_POD> -c grafana
```

Expected database type:

```text
mysql
```

Expected Grafana startup:

```text
Connecting to DB dbtype=mysql
Starting DB migrations
migrations completed
```

Expected Vault authentication:

```text
policies:
  grafana-read
```

---

# 29. Final Expected Flow

When everything is configured correctly:

```text
Grafana Pod
    │
    │ Kubernetes ServiceAccount
    ▼
Vault Kubernetes Auth
    │
    │ vault-role
    ▼
grafana-read Policy
    │
    │ read
    ▼
secret/data/mysql-secret
    │
    │ Vault Agent renders
    ▼
/vault/secrets/mysql-secret
    │
    │ source
    ▼
Grafana Environment
    │
    ├── GF_DATABASE_TYPE=mysql
    ├── GF_DATABASE_HOST=<MYSQL-HOST>
    ├── GF_DATABASE_PORT=3306
    ├── GF_DATABASE_NAME=grafana
    ├── GF_DATABASE_USER=<USER>
    └── GF_DATABASE_PASSWORD=<PASSWORD>
    │
    ▼
MySQL / RDS
    │
    ▼
Grafana
```

Once the flow above is working, Grafana obtains its MySQL credentials from Vault without storing the database password directly in the Grafana Helm values.
