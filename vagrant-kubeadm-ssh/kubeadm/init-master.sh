#!/bin/bash

echo ">>> INIT MASTER NODE"

sudo systemctl enable kubelet

kubeadm init \
  --apiserver-advertise-address=$MASTER_NODE_IP \
  --pod-network-cidr=$K8S_POD_NETWORK_CIDR \
  --ignore-preflight-errors=NumCPU \
  --v=5
sudo kubeadm init \
  --pod-network-cidr=$K8S_POD_NETWORK_CIDR \
  --service-cidr=$K8S_SERVICE_CIDR \
  --control-plane-endpoint=k8s-master \
  --apiserver-advertise-address=$MASTER_NODE_IP \
  --v=5


echo ">>> CONFIGURE KUBECTL"

sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

mkdir -p /home/vagrant/.kube
sudo cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown 900:900 /home/vagrant/.kube/config

sudo cp -i /etc/kubernetes/admin.conf /vagrant/kubeadm/admin.conf

echo ">>> FIX KUBELET NODE IP"

echo "Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$MASTER_NODE_IP\"" | sudo tee -a /var/lib/kubelet/kubeadm-flags.env


if [ "$K8S_POD_NETWORK_TYPE" == "cilium" ]
then 
  echo ">>> DEPLOY POD NETWORK > CILIUM"
  /vagrant/cni/cilium/scripts/cilium.sh 
fi


sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo ">>> GET WORKER JOIN COMMAND "

rm -f /vagrant/kubeadm/init-worker.sh
kubeadm token create --print-join-command >> /vagrant/kubeadm/init-worker.sh


