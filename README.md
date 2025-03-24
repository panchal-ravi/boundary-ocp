## create new project
```
oc new-project boundary
```

## deploy postgres in the above project
```
k apply -f ./postgresql.yaml
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
k create cm boundary-controller-config --from-file=./boundary-controller.hcl
```

## create configmap for boundary-license
```
k create cm boundary-license --from-file=./license.hclic
```

Review `POSTGRESQL_CONNECTION_STRING` in the `boundary-controller.yaml` file
Update `host` value for `boundary-cluster` and `boundary-api` routes
## Deploy boundary controller
```
k apply -f ./boundary-controller.yaml
```
Check boundary-controller logs for any errors.
Update `public_addr` and `initial_upstreams` in `boundary-worker.hcl` file
```
oc get routes boundary-cluster -ojson | jq .spec.host -r
```

## create configmap for boundary-worker
```
k create cm boundary-worker-config --from-file=./boundary-worker.hcl
```

Update "host" under Routes specification in boundary-worker.yaml
## Deploy boundary worker
```
k apply -f ./boundary-worker.yaml
```

Retrieve worker auth token from the boundary-worker pod
## Register worker using this token
b workers create worker-led -worker-generated-auth-token=$TOKEN

## deploy DB2 in the above project
```
oc create role db2-default -n boundary --verb=use --resource=scc --resource-name=privileged
oc create rolebinding db2-default -n boundary --role=db2-default --serviceaccount=boundary:default
k apply -f ./db2.yaml

#verify db2 status and connectivity 
k exec -it <db2-pod-name> -- sh
su -i db2inst1
db2sampl -force -sql

db2 connect to sample
db2 LIST TABLES
```

## Delete all
```
k delete -f ./boundary-worker.yaml
k delete -f ./boundary-controller.yaml
k delete -f ./postgresql.yaml
k delete -f ./db2.yaml

k delete cm boundary-worker-config
k delete cm boundary-license
k delete cm boundary-controller-config
```