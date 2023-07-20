#!/bin/bash


echo ">>> SYSTEM UPDATE & UPGRADE"

sudo yum update -y


echo ">>> DISABLE SWAP"

sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab



echo ">>> KERNEL MODULES"

sudo echo br_netfilter > /etc/modules-load.d/k8s.conf
sudo echo overlay > /etc/modules-load.d/k8s.conf

sudo modprobe overlay
sudo modprobe br_netfilter	 
	 
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

lsmod | grep br_netfilter
lsmod | grep overlay

sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward



echo ">>> INSTALLING CONTAINERD CRI FROM DNF"

sudo yum install -y podman
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# docker was deprecated in RHEL distributions, so stick to podman
sudo yum update -y && yum install -y containerd.io

# refresh the config, this will help you avoid some issues I encountered earlier
sudo mkdir -p /etc/containerd 
sudo containerd config default > /etc/containerd/config.toml

sudo systemctl restart containerd && sudo systemctl enable containerd




echo ">>> CONFIGURING SYSTEMD CGROUP DRIVER and SANDBOX (PAUSE) IMAGE"

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's/3.6/3.9/g' /etc/containerd/config.toml

sudo systemctl restart containerd




echo ">>> ADDING THE KUBERNETES YUM REPO"

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF



echo ">>> SET SELINUX and INSTALL KUBE-* TOOLS"

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum erase -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo dnf install -y kubelet-$VERSION kubeadm-$VERSION kubectl-$VERSION --disableexcludes=kubernetes

systemctl enable --now kubelet && systemctl start kubelet


echo ">>> PREPARE ENVIRONMENT"
echo "alias k=kubectl" >> ~/.bash_profile
echo "source <(kubectl completion bash)" >> ~/.bash_profile
echo "source <(kubectl completion bash | sed s/kubectl/k/g)" >> ~/.bash_profile
. .bash_profile
