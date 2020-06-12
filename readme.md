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
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM
```

```
aws --profile secondary cloudformation deploy \
--template-file infrastructure/infrastructure_secondary.yaml \
--stack-name am-multi-account-infra \
--capabilities CAPABILITY_IAM
```

## Share Subnets

```
aws --profile primary cloudformation deploy \
--template-file shared_resources/shared_subnets.yaml \
--parameter-overrides "SecondaryAccountId=265506693770" \
--stack-name am-multi-account-shared-subnets \
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

<!--```
kubectl apply -f \
https://raw.githubusercontent.com/M00nF1sh/aws-app-mesh-controller-for-k8s/v1beta2_bugbash/config/samples/crd.yaml
```-->

```
kubectl apply --validate=false -f \
https://github.com/jetstack/cert-manager\
/releases/download/v0.15.0/cert-manager.yaml

kubectl -n cert-manager get pods
```

```
kubectl apply -f \
https://raw.githubusercontent.com\
/M00nF1sh/aws-app-mesh-controller-for-k8s\
/v1beta2_bugbash/config/samples/deploy.yaml

kubectl -n appmesh-system get pods
```

## Deploy and Share Mesh

```
kubectl create ns yelb
kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
kubectl apply -f mesh/selector.yaml
```

```
aws --profile primary cloudformation deploy \
--template-file shared_resources/shared_mesh.yaml \
--parameter-overrides "SecondaryAccountId=265506693770" \
--stack-name am-multi-account-shared-mesh \
--capabilities CAPABILITY_IAM
```

## Deploy the App Mesh Controller on our Secondary Cluster

```
kubectl config use-context gfvieira@am-multi-account-2.us-west-2.eksctl.io
```

<!--```
kubectl apply -f https://raw.githubusercontent.com/M00nF1sh/aws-app-mesh-controller-for-k8s/v1beta2_bugbash/config/samples/crd.yaml
```-->

```
kubectl apply --validate=false -f \
https://github.com/jetstack/cert-manager\
/releases/download/v0.15.0/cert-manager.yaml

kubectl -n cert-manager get pods
```

```
kubectl apply -f \
https://raw.githubusercontent.com\
/M00nF1sh/aws-app-mesh-controller-for-k8s\
/v1beta2_bugbash/config/samples/deploy.yaml

kubectl -n appmesh-system get pods
```

## Deploy Mesh Resources on our Secondary Cluster

```
kubectl create ns yelb

kubectl label namespace yelb mesh=am-multi-account-mesh
kubectl label namespace yelb "appmesh.k8s.aws/sidecarInjectorWebhook"=enabled
```

```
kubectl apply -f mesh/selector.yaml
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

```
kubectl apply -f mesh/yelb-ui.yaml
```

## Deploy Yelb Resources on our Primary Cluster

```
kubectl apply -f yelb/resources_primary.yaml
```


