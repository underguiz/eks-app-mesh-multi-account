## Configure Primary and Secondary Account Profiles

```
cat ~/.aws/credentials

[default]
aws_access_key_id =  ...
aws_secret_access_key = ...
[primary]
aws_access_key_id =  ...
aws_secret_access_key = ...
[secondary]
aws_access_key_id = ...
aws_secret_access_key = ...
```

## Deploy the Infrastructure

```
aws --profile primary cloudformation deploy \
--template-file infrastructure/infrastructure_primary.yaml \
--parameter-overrides \
"SecondaryAccountId=$(aws --profile secondary sts get-caller-identity | jq -r .Account)" \
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM
```

```
aws --profile secondary cloudformation deploy \
--template-file infrastructure/infrastructure_secondary.yaml \
--parameter-overrides \
"PrimaryAccountId=$(aws --profile primary sts get-caller-identity | jq -r .Account)" \
"PeerVPCId=$(aws --profile primary cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPC") | .Value')" \
"PeerRoleArn=$(aws --profile primary cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPCPeerRole") | .Value')" \
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM
```

```
aws --profile primary cloudformation deploy \
--template-file infrastructure/primary_vpc_peering_routes.yaml \
--parameter-overrides \
"VPCPeeringConnectionId=$(aws --profile secondary cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:VPCPeeringConnectionId") | .Value')" \
--stack-name am-multi-account-routes \
--capabilities CAPABILITY_IAM
```

```
aws --profile secondary cloudformation deploy \
--template-file infrastructure/secondary_vpc_peering_routes.yaml \
--stack-name am-multi-account-routes \
--capabilities CAPABILITY_IAM
```


## Deploy EKS

```
./eks/eksctl_config_primary.sh
./eks/eksctl_config_secondary.sh
```

## Deploy the App Mesh Controller on our Primary Cluster

```
kubectl config use-context gfvieira@am-multi-account-1.us-west-2.eksctl.io
```

```
helm repo add eks https://aws.github.io/eks-charts
```

```
kubectl create ns appmesh-system
helm upgrade -i appmesh-controller eks/appmesh-controller \
--namespace appmesh-system

kubectl -n appmesh-system get pods
```

## Deploy and Share Mesh

```
kubectl create ns yelb
kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
./mesh/create_mesh.sh
```

```
aws --profile primary cloudformation deploy \
--template-file shared_resources/shared_mesh.yaml \
--parameter-overrides \
"SecondaryAccountId=$(aws --profile secondary sts get-caller-identity | jq -r .Account)" \
--stack-name am-multi-account-shared-mesh \
--capabilities CAPABILITY_IAM
```

_Accept Resource Share Invitation Steps._

## Deploy the App Mesh Controller on our Secondary Cluster

```
kubectl config use-context gfvieira@am-multi-account-2.us-west-2.eksctl.io
```

```
helm repo add eks https://aws.github.io/eks-charts
```

```
kubectl create ns appmesh-system
helm upgrade -i appmesh-controller eks/appmesh-controller \
--namespace appmesh-system

kubectl -n appmesh-system get pods
```

## Create the App Mesh Service Role on our Secondary Account

```
aws --profile secondary iam create-service-linked-role --aws-service-name appmesh.amazonaws.com
```

## Deploy Mesh Resources on our Secondary Cluster

```
kubectl create ns yelb

kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
./mesh/create_mesh.sh

kubectl apply -f mesh/yelb-redis.yaml
kubectl apply -f mesh/yelb-db.yaml
kubectl apply -f mesh/yelb-appserver.yaml
```

## Deploy Yelb Resources on our Secondary Cluster

```
kubectl apply -f yelb/resources_secondary.yaml
```

## Deploy Mesh Resources on our Primary Cluster

```
kubectl config use-context gfvieira@am-multi-account-1.us-west-2.eksctl.io
```

Get the ```yelb-appserver``` VirtualService ARN and change ```mesh/yelb-ui.yaml``` accordingly. 

```
kubectl --context=gfvieira@am-multi-account-2.us-west-2.eksctl.io \
-n yelb get virtualservice yelb-appserver
```

```
kubectl apply -f mesh/yelb-ui.yaml
```

## Deploy Yelb Resources on our Primary Cluster

```
kubectl apply -f yelb/resources_primary.yaml
```




