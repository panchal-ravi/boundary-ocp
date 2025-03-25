## create new project
```
oc new-project boundary
```

## deploy postgres in the above project
```
kubectl apply -f ./postgresql.yaml
```

## test postgresql 
```
kubectl run -it alpine --image=alpine --restart=Never
apk add postgresql-client
psql -h postgres.boundary.svc.cluster.local -U postgres
\l
```

## delete test pod 
```
kubectl delete pod alpine
```

## Get the domain name
```
oc get routes -n openshift-authentication oauth-openshift -ojson | jq .spec.host -r | cut -d '.' -f 2-
```

Update `public_cluster_address` field in `boundary-controller.hcl` using the domain name from above output
## create configmap for boundary-controller 
```
kubectl create cm boundary-controller-config --from-file=./boundary-controller.hcl
```

## create configmap for boundary-license
```
kubectl create cm boundary-license --from-file=./license.hclic
```

Review `POSTGRESQL_CONNECTION_STRING` in the `boundary-controller.yaml` file
Update `host` value for `boundary-cluster` and `boundary-api` routes
## Deploy boundary controller
```
kubectl apply -f ./boundary-controller.yaml
```
Check boundary-controller logs for any errors.
Update `public_addr` and `initial_upstreams` in `boundary-worker.hcl` file
```
oc get routes boundary-cluster -ojson | jq .spec.host -r
```

## create configmap for boundary-worker
```
kubectl create cm boundary-worker-config --from-file=./boundary-worker.hcl
```

Update "host" under Routes specification in boundary-worker.yaml
## Deploy boundary worker
```
kubectl apply -f ./boundary-worker.yaml
```

Retrieve worker auth token from the boundary-worker pod
## Register worker using this token
boundary workers create worker-led -worker-generated-auth-token=$TOKEN

## deploy DB2
```
oc create role db2-default -n boundary --verb=use --resource=scc --resource-name=privileged
oc create rolebinding db2-default -n boundary --role=db2-default --serviceaccount=boundary:default
kubectl apply -f ./db2.yaml

#verify db2 status and connectivity 
kubectl exec -it <db2-pod-name> -- sh
su -i db2inst1
db2sampl -force -sql

db2 connect to sample
db2 LIST TABLES
```

## Deploy Vault
```sh
kubectl apply -f ./vault.yaml
```

## Configure kubernetes secret engine
```sh
kubectl apply -f ./vault-sa.yaml

export VAULT_ADDR=https://$(oc get routes -ojson | jq '.items[] | select(.metadata.name == "vault") | .status.ingress[].host' -r)
export VAULT_TOKEN=root
vault secrets enable kubernetes

export KUBERNETES_HOST=$(k config view --minify -o json | jq '.clusters[0].cluster.server' -r)
export SA_SECRET=$(k get secrets -ojson | jq '.items[] | select (.type == "kubernetes.io/service-account-token" and .metadata.annotations."kubernetes.io/service-account.name" == "vault-admin") | .metadata.name' -r)
export SA_TOKEN=$(k get secrets $SA_SECRET -o json | jq .data.token -r | base64 -d)
export CA_CERT=$(k get secrets $SA_SECRET -o json | jq '.data."ca.crt"' -r | base64 -d)

vault write -f kubernetes/config \
    service_account_jwt=$SA_TOKEN \
    kubernetes_host=$KUBERNETES_HOST \
    kubernetes_ca_cert=$CA_CERT \
    disable_local_ca_jwt=false

export ROLE_RULES=$(cat <<-EOF
{
    "rules":[
        {
          "apiGroups":[""],
          "resources":["pods", "services", "persistentvolumeclaims"],
          "verbs":["get", "list", "watch"]
        },
        {
          "apiGroups":["extensions", "apps"],
          "resources":["deployments", "replicasets", "statefulsets"],
          "verbs":["get", "list", "watch"]
        }
    ]
}
EOF
)

vault write kubernetes/roles/my-role \
    allowed_kubernetes_namespaces="*" \
    token_default_ttl="10m" \
    token_max_ttl="10m" \
    generated_role_rules=$ROLE_RULES
``` 

## Create vault credential store
```sh
vault policy write boundary ./vault-policy-for-boundary.hcl

# create vault token for boundary
export VAULT_BOUNDARY_TOKEN=$(vault token create -no-default-policy=true -orphan=true -period=20m -renewable=true -policy="boundary" -format=json | jq .auth.client_token -r)

## Ensure you are logged into Boundary as an administrator
export PROJECT_ID=$(boundary scopes list -scope-id global -recursive -format json | jq '.items[] | select(.scope.type=="org") | .id' -r)
export VAULT_CRED_STORE_ID=$(boundary credential-stores create vault \
    -vault-address $VAULT_ADDR \
    -vault-token $VAULT_BOUNDARY_TOKEN \
    -scope-id $PROJECT_ID \
    -name vault-cred-store \
    -description "Vault credential store" -format json | jq ".item.id" -r)

## Create vault credential library for Kubernetes
export REQUEST_BODY=$(cat <<-EOF
{
  "kubernetes_namespace": "test"
}
EOF
)

boundary credential-libraries create vault-generic -credential-store-id=$VAULT_CRED_STORE_ID -vault-path="kubernetes/creds/my-role" -vault-http-method="POST" -vault-http-request-body=$REQUEST_BODY
```

## Create boundary target for OCP
```sh
export OCP_ADDR=$(k config view --minify -o json | jq '.clusters[0].cluster.server' -r | cut -d/ -f3)
export OCP_PORT=$(k config view --minify -o json | jq '.clusters[0].name'  -r | cut -d':' -f2)
export OCP_TARGET_ID=$(boundary targets create tcp -name=ocp_readonly -address=$OCP_ADDR -default-port=$OCP_PORT -scope-id=$PROJECT_ID -format=json | jq .item.id -r)
export CRED_SOURCE_ID=$(boundary credential-libraries list -credential-store-id=$VAULT_CRED_STORE_ID -format=json | jq '.items[].id' -r)

boundary targets add-credential-sources -id=$OCP_TARGET_ID -brokered-credential-source=$CRED_SOURCE_ID 
```


## Delete all
```
kubectl delete cm boundary-worker-config
kubectl delete cm boundary-license
kubectl delete cm boundary-controller-config

kubectl delete -f ./boundary-worker.yaml
kubectl delete -f ./boundary-controller.yaml
kubectl delete -f ./postgresql.yaml
kubectl delete -f ./db2.yaml
kubectl delete -f ./vault-sa.yaml
kubectl delete -f ./vault.yaml
```