#!/bin/bash
export BOUNDARY_SCOPE_NAME=$(boundary scopes read -id $PROJECT_ID -format=json | jq .item.name -r)
nohup boundary connect -target-name ocp_readonly -target-scope-name="$BOUNDARY_SCOPE_NAME" -format=json | tee ./test-boundary-kube.json 1>/dev/null &
sleep 2

rm ./test-kubeconfig
touch ./test-kubeconfig
export KUBECONFIG=./test-kubeconfig
export CLUSTER_NAME=My-Kubernetes-Cluster
export PORT=$(cat ./test-boundary-kube.json | jq .port)
export REMOTE_USER_TOKEN=$(cat ./test-boundary-kube.json | jq -r '.credentials[].secret.decoded.service_account_token')

echo "Cluster name is: ${CLUSTER_NAME}"
echo "Port number is: ${PORT}"
echo "Configuring Kubernetes contexts..."

kubectl config set-cluster $CLUSTER_NAME \
  --server=https://127.0.0.1:$PORT \
  --tls-server-name kubernetes \
  --insecure-skip-tls-verify=true

kubectl config set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME
kubectl config set-credentials boundary-user --token=$REMOTE_USER_TOKEN
kubectl config set-context $CLUSTER_NAME --user=boundary-user --namespace test
kubectl config use-context $CLUSTER_NAME
