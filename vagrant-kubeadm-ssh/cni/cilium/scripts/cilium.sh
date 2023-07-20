#!/bin/bash

POD_CIDR=172.16.0.0/16
# Kubeadm default is 6443
MASKSIZE=24


echo ">>> DOWNLOADING CILIUM"

sudo wget https://get.helm.sh/helm-v3.12.2-linux-amd64.tar.gz

sudo tar -xvf helm-v3.12.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin

sudo rm helm-v3.12.2-linux-amd64.tar.gz
sudo rm -rf linux-amd64

/usr/local/bin/helm version

echo ">>> INSTALLING CILIUM"

sudo /usr/local/bin/helm repo add cilium https://helm.cilium.io/
sudo /usr/local/bin/helm install cilium cilium/cilium \
    --namespace kube-system \
    --set ipam.operator.clusterPoolIPv4PodCIDRList=${POD_CIDR} \
    --set ipam.operator.clusterPoolIPv4MaskSize=${MASKSIZE} 


