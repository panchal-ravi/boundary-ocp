## create new project
oc new-project boundary

## deploy postgres in the above project
k apply -f ./postgresql.yaml

## test postgresql
kubectl run -it alpine --image=alpine --restart=Never
apk add postgresql-client
psql -h postgres.boundary.svc.cluster.local -U postgres
\l

kubectl delete pod alpine

## Get the domain name
oc get routes -n openshift-authentication oauth-openshift -ojson | jq .spec.host -r | cut -d '.' -f 2-

<!-- 
Update "public_cluster_address" field in boundary-controller.hcl using the domain name from above output
create configmap for boundary-controller 
-->
k create cm boundary-controller-config --from-file=./boundary-controller.hcl

## create configmap for boundary-license
k create cm boundary-license --from-file=./license.hclic

<!-- Review POSTGRESQL_CONNECTION_STRING in the boundary-controller.yaml -->
## Deploy boundary controller
k apply -f ./boundary-controller.yaml

<!-- Check boundary-controller logs for any errors. -->
<!-- Update "public_addr" in boundary-worker.hcl ->

> oc get routes boundary-controller -ojson | jq .spec.host -r

## create configmap for boundary-worker
k create cm boundary-worker-config --from-file=./boundary-worker.hcl

# Update "host" under Routes specification 
# Deploy boundary controller
k apply -f ./boundary-worker.yaml


#### Delete all

k delete -f ./boundary-worker.yaml
k delete -f ./boundary-controller.yaml
k delete -f ./postgresql.yaml

k delete cm boundary-worker-config
k delete cm boundary-license
k delete cm boundary-controller-config
