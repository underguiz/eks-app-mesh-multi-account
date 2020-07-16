#!/bin/bash

# Create a ClusterConfig file
AWS_REGION="us-west-2"
PRIVSUB1_ID=$(aws --profile primary-vpcp cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet1") | .Value');
PRIVSUB2_ID=$(aws --profile primary-vpcp cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PrivateSubnet2") | .Value');
PUBSUB1_ID=$(aws --profile primary-vpcp cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet1") | .Value');
PUBSUB2_ID=$(aws --profile primary-vpcp cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:PublicSubnet2") | .Value');
PRIVSUB1_AZ=$(aws --profile primary-vpcp ec2 describe-subnets --subnet-ids $PRIVSUB1_ID | jq -r .Subnets[].AvailabilityZone);
PRIVSUB2_AZ=$(aws --profile primary-vpcp ec2 describe-subnets --subnet-ids $PRIVSUB2_ID | jq -r .Subnets[].AvailabilityZone);
PUBSUB1_AZ=$(aws --profile primary-vpcp ec2 describe-subnets --subnet-ids $PUBSUB1_ID | jq -r .Subnets[].AvailabilityZone);
PUBSUB2_AZ=$(aws --profile primary-vpcp ec2 describe-subnets --subnet-ids $PUBSUB2_ID | jq -r .Subnets[].AvailabilityZone);
NODES_IAM_POLICY=$(aws --profile primary-vpcp cloudformation list-exports | jq -r '.Exports[] | select(.Name=="am-multi-account:NodesSDPolicy") | .Value');

cat > /tmp/eks-1-configuration.yml <<-EKS_CONF
  apiVersion: eksctl.io/v1alpha5
  kind: ClusterConfig  
  metadata:
    name: am-multi-account-1
    region: $AWS_REGION
    version: "1.16"
  vpc:
    subnets:
      private:
        $PRIVSUB1_AZ: { id: $PRIVSUB1_ID }
        $PRIVSUB2_AZ: { id: $PRIVSUB2_ID }
      public:
        $PUBSUB1_AZ: { id: $PUBSUB1_ID }
        $PUBSUB2_AZ: { id: $PUBSUB2_ID }
  nodeGroups:
    - name: am-multi-account-1-ng
      labels: { role: workers }
      instanceType: t3.large
      desiredCapacity: 3
      ssh: 
        allow: false
      privateNetworking: true
      iam:
        attachPolicyARNs: 
          - $NODES_IAM_POLICY
          - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
          - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          - arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
          - arn:aws:iam::aws:policy/AWSAppMeshFullAccess
        withAddonPolicies:
          xRay: true
          cloudWatch: true
          externalDNS: true
EKS_CONF

# Create the EKS cluster
eksctl create -p primary-vpcp cluster -f /tmp/eks-1-configuration.yml