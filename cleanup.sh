#!/bin/bash

set -e
export AWS_PAGER=""

echo "Deleting EKS clusters"
eksctl delete -p primary cluster -f /tmp/eks-1-configuration.yml
eksctl delete -p secondary cluster -f /tmp/eks-2-configuration.yml

echo "Deleting the App Mesh virtual services"
aws --profile primary appmesh delete-virtual-service \
    --mesh-name am-multi-account-mesh \
    --virtual-service-name yelb-db

aws --profile primary appmesh delete-virtual-service \
    --mesh-name am-multi-account-mesh \
    --virtual-service-name redis-server

aws --profile primary appmesh delete-virtual-service \
    --mesh-name am-multi-account-mesh \
    --virtual-service-name yelb-appserver

aws --profile primary appmesh delete-virtual-service \
    --mesh-name am-multi-account-mesh \
    --virtual-service-name yelb-ui

echo "Deleting the App Mesh virtual router"
aws --profile primary appmesh delete-route \
    --mesh-name am-multi-account-mesh \
    --virtual-router-name yelb-appserver-virtual-router \
    --route-name route-to-yelb-appserver

aws --profile primary appmesh delete-virtual-router \
    --mesh-name am-multi-account-mesh \
    --virtual-router-name yelb-appserver-virtual-router

echo "Deleting the App Mesh virtual nodes"
aws --profile primary appmesh delete-virtual-node \
    --mesh-name am-multi-account-mesh \
    --virtual-node-name redis-server_yelb

aws --profile primary appmesh delete-virtual-node \
    --mesh-name am-multi-account-mesh \
    --virtual-node-name yelb-db_yelb

aws --profile primary appmesh delete-virtual-node \
    --mesh-name am-multi-account-mesh \
    --virtual-node-name yelb-appserver_yelb

aws --profile primary appmesh delete-virtual-node \
    --mesh-name am-multi-account-mesh \
    --virtual-node-name yelb-ui_yelb

echo "Deleting the App Mesh mesh"
aws --profile primary appmesh delete-mesh \
    --mesh-name am-multi-account-mesh

echo "Deleting Cloud Map Services"
NAMESPACE=$(aws --profile secondary servicediscovery list-namespaces | \
  jq -r ' .Namespaces[] | select ( .Properties.HttpProperties.HttpName == "am-multi-account.local" ) | .Id ');
SERVICE_ID=$(aws --profile secondary servicediscovery list-services --filters Name="NAMESPACE_ID",Values=$NAMESPACE,Condition="EQ" | jq -r ' .Services[] | [ .Id ] | @tsv ' )
aws --profile secondary servicediscovery list-instances --service-id $SERVICE_ID | jq -r ' .Instances[] | [ .Id ] | @tsv ' |\
  while IFS=$'\t' read -r instanceId; do 
    aws --profile secondary servicediscovery deregister-instance --service-id $SERVICE_ID --instance-id $instanceId
  done
aws --profile secondary servicediscovery list-services \
  --filters Name="NAMESPACE_ID",Values=$NAMESPACE,Condition="EQ" | \
jq -r ' .Services[] | [ .Id ] | @tsv ' | \
  while IFS=$'\t' read -r serviceId; do 
    aws --profile secondary servicediscovery delete-service \
      --id $serviceId
  done

echo "Deleting CloudFormation templates"
aws --profile secondary cloudformation delete-stack \
  --stack-name am-multi-account-routes
aws --profile secondary cloudformation wait stack-delete-complete \
  --stack-name am-multi-account-routes

aws --profile secondary cloudformation delete-stack \
  --stack-name am-multi-account-infra
aws --profile secondary cloudformation wait stack-delete-complete \
  --stack-name am-multi-account-infra

aws --profile primary cloudformation delete-stack \
  --stack-name am-multi-account-shared-mesh
aws --profile primary cloudformation wait stack-delete-complete \
  --stack-name am-multi-account-shared-mesh

aws --profile primary cloudformation delete-stack \
  --stack-name am-multi-account-routes
aws --profile primary cloudformation wait stack-delete-complete \
  --stack-name am-multi-account-routes

aws --profile primary cloudformation delete-stack \
  --stack-name am-multi-account-infra
aws --profile primary cloudformation wait stack-delete-complete \
  --stack-name am-multi-account-infra

echo "Cleanup finished"