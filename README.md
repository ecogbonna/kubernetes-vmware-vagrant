# kubernetes
Some YAML files were adopted from my Google partner labs and will be used as starters for my other kubernetes implementations.
There are also files from Kubernetes in Action book by Marko Lukša. In fact, I used this book mostly.


## Kubernetes on-prem build: Installing Kubernetes on OEL9 using kubeadm


## Pre-Installation
```shell
# Prepare users:
sudo useradd <chieme>
sudo passwd <chieme>

echo "chieme  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/chieme
```
</br>
</br>

## Installing Docker and Kubernetes

Prerequisites:
	
	• A compatible Linux host. The Kubernetes project provides generic instructions for Linux distributions based on Debian and Red Hat, and those distributions without a package manager.
	• 2 GB or more of RAM per machine (any less will leave little room for your apps).
	• 2 CPUs or more.
	• Full network connectivity between all machines in the cluster (public or private network is fine).
	• Unique hostname, MAC address, and product_uuid for every node. See here for more details.
	• Certain ports are open on your machines. See here for more details.
	• Swap disabled. You MUST disable swap in order for the kubelet to work properly.


Steps:
1. Installing kubeadm: Configuring the master with kubeadm
	- CONFIGURE LINUX COMPONENTS (MAC Address, Network adapters, Ports, SWAP)
	- Installing a container runtime
		- Install and configure prerequisites 
			- Forwarding IPv4 and letting iptables see bridged traffic (sysctl)
		- Container runtime: installing containerd from apt-get or dnf
		- cgroup drivers
			- systemd cgroup driver (recommended)
				- Configuring the systemd cgroup driver: containerd
	- Installing kubeadm, kubelet and kubectl
2. Cloning the Master node to create worker nodes: remember to change MAC Address IP, and hostname
3. Initializing your control-plane node.
	- plan for high availability by specifying the --control-plane-endpoint to set the shared endpoint for all control-plane nodes. (Recommended) 
	- Choose a Pod network add-on, and verify whether it requires any arguments to be passed to kubeadm init: flannel requires --pod-network-cidr (Recommended) 
4. Save the node join command with the token.
5. Join the worker node to the master node (control plane) using kubeadm join command.
6. Install and Validate Cilium CNI for flat-inter-pod networking.
7. Validate all cluster components and nodes.
8. Install Kubernetes Metrics Server
9. Using the cluster from your local machine
	- (Optional) Controlling your cluster from machines other than the control-plane node
10. (Optional) Proxying API Server to localhost
11. Cleanup

</br>
</br>

### 1. Installing kubeadm: Configuring the master with kubeadm
#### Configure Linux Components (SELinux, SWAP and sysctl)

##### Verify the MAC address and product_uuid are unique for every node

> we will ensure this during VM Cloning


##### CHECK NETWORK ADAPTERS

> we're using only bridge network adapter....much simpler to manage



##### DISABLING SWAP
The Kubelet won’t run if swap is enabled, so you’ll disable it with the following command:

```shell
# disable swap
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

</br>

#### Installing a container runtime
##### Install and configure prerequisites

```shell
# Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF	
 
sudo modprobe overlay
sudo modprobe br_netfilter	  
	 
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system	 
	

# Verify that the br_netfilter, overlay modules are loaded by running the following commands:

lsmod | grep br_netfilter
lsmod | grep overlay	 

# Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system variables are set to 1 in your sysctl config by running the following command:

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

```

##### Container Runtime: Installing Containerd from apt-get or dnf


---
**NOTE**

*1. You need a container engine, high-level container runtime, and a low-level container runtime.*

*2. On OEL9, no need to install docker. RHEL distributions will have podman installed already.*

*3. I chose containerd (i.e. podman -> containerd -> runc), you can go with CRI-O, Docker Engine (cri-dockerd adapter), or Mirantis Container Runtime.*

---

```shell
# which podman
/usr/bin/podman
[root@master ~]# podman version
Client:       Podman Engine
Version:      4.4.1
API Version:  4.4.1
Go Version:   go1.19.6
Built:        Fri May 12 09:55:18 2023
OS/Arch:      linux/amd64
```





##### Install required packages
```shell 
# Install required packages
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# Add Docker repo
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo


# docker was deprecated in RHEL distributions, so stick to podman
sudo yum update -y && yum install -y containerd.io


# refresh the config, this will help you avoid some issues I encountered earlier
sudo mkdir -p /etc/containerd 
sudo containerd config default > /etc/containerd/config.toml

sudo systemctl restart containerd && sudo systemctl enable containerd

```

Links:
1. [containerd github](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
2. [containerd docker](https://docs.docker.com/engine/install/centos/)
3. [containerd computingforgeeks](https://computingforgeeks.com/)
4. [kubernetes containerd](install-kubernetes-cluster-on-centos-with-kubeadm/?amp)




##### Configuring the systemd cgroup driver
---
**NOTE**

To use the systemd cgroup driver in /etc/containerd/config.toml with runc, set:

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

```shell
vi /etc/containerd/config.toml
sudo systemctl restart containerd
```
---




##### Overriding The Sandbox (Pause) Image
In your containerd config you can overwrite the sandbox image by setting the following config:

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
  
  
sudo systemctl restart containerd
 

> Do this to avoid WARNINGs during kubeadm init. kubeadm uses 3.9, but containered used 3.6



</br>

#### INSTALLING kubeadm, kubelet and kubectl
##### ADDING THE KUBERNETES YUM REPO

```shell 
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

	# Make sure no whitespace exists after EOF if you’re copying and pasting
	
	
	
# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum erase -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo dnf install -y kubelet-1.26.1 kubeadm-1.26.1 kubectl-1.26.1 --disableexcludes=kubernetes

systemctl enable --now kubelet && systemctl start kubelet

```



##### CONFIGURING NAME RESOLUTION FOR ALL THREE HOSTS

```shell 
# Kubernetes Bridged Adapter 
192.168.1.30   k8s-master  k8s-master.localdomain
192.168.1.31   k8s-node1  k8s-node1.localdomain
192.168.1.32   k8s-node2  k8s-node2.localdomain

192.168.1.70   master  master.localdomain
192.168.1.71   node1  node1.localdomain
192.168.1.72   node2  node2.localdomain
```




</br>
</br>

### 2. CLONING THE VM

```shell 
shutdown now
```

##### CREATING OTHER NODES from k8s-master (repeat for all VMs):
Next, we will create the additional host or hosts that are required, and make the changes to those hosts needed to complete the build of an Oracle RAC.

Steps:
1. Shutdown existing VM guest 'shutdown -h now', 

2. from VMware workstation, choose Manage=>clone.

3. current state -> full clone -> name and location (should've created folder)

4. When completed, click close. Do not start up the new host yet. There are some settings that need to be changed

5. Assign new MAC addresses to the NICs in the VM
Any routers that used reserved IPs will use the MAC address to assign them, so we want to make sure this workstation has different MAC addresses than the original

VM Settings -> Network Adapter -> Advanced -> MAC address -> generate
Do the same for each Network Interface card (NIC) (bridged, NAT, host-only): In this case, I delete other adapters and used only bridged adapter

6. power on VM

7. Login as root
Network settings -> set IP addresses as done before (Public n Private Network setup)

8. set hostname: run as root or any sudoer
```shell
hostnamectl set-hostname <node1>
```

9. Reboot
```shell
reboot
```



##### CHECK REQUIRED PORTS:

```shell
# ON MASTER NODE:
sudo firewall-cmd --add-port={443,6443,2379-2380,10250,10251,10252,5473,179,4240-4245,6060-6062,9879-9893,9962-9964}/tcp --permanent
sudo firewall-cmd --add-port={4789,8285,8472,51871}/udp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all


# ON WORKER NODES:
Enter the following commands on each worker node:

sudo firewall-cmd --add-port={443,10250,30000-32767,5473,179,5473,4240-4245,9879-9893,9962-9964}/tcp --permanent
sudo firewall-cmd --add-port={4789,8285,8472,51871}/udp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

# if you will use another CNI, please check their system requirements
```

Link: 
1. [kubernetes ports-and-protocols](https://kubernetes.io/docs/reference/networking/ports-and-protocols/)
2. [cilium system requirements](https://docs.cilium.io/en/stable/operations/system_requirements/)
							



</br>
</br>

### 3. Running `kubeadm Init` to initialize the master
```shell
# check the --pod-network-cidr requirements for your CNI of choice e.g. Flannel uses --pod-network-cidr=10.244.0.0/16

# sudo kubeadm init \
  --service-cidr=10.64.0.0/20\
  --control-plane-endpoint=master --dry-run >> init.log
  
# # sudo kubeadm init \
  --service-cidr=10.64.0.0/20 \
  --control-plane-endpoint=master \
  --apiserver-advertise-address=192.168.1.70

...
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join master:6443 --token 68f0ys.jwfefd7r03lqtupm \
        --discovery-token-ca-cert-hash sha256:cad6144cd55c8f0f91e1ff205e3ba2a465ea5b9bd866c43f58230f4546eab281 \
        --control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join master:6443 --token 68f0ys.jwfefd7r03lqtupm \
        --discovery-token-ca-cert-hash sha256:cad6144cd55c8f0f91e1ff205e3ba2a465ea5b9bd866c43f58230f4546eab281
		
		
# --control-plane-endpoint=master makes it possible to join any number of control-plane nodes i.e. for HA clusters, without it, we can only join worker nodes

```

</br>
</br>

### 4. Configuring worker nodes with kubeadm

```shell
kubeadm join master:6443 --token 68f0ys.jwfefd7r03lqtupm \
        --discovery-token-ca-cert-hash sha256:cad6144cd55c8f0f91e1ff205e3ba2a465ea5b9bd866c43f58230f4546eab281
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

# kubectl get nodes
NAME     STATUS     ROLES           AGE     VERSION
master   NotReady   control-plane   30m     v1.26.1
node1    NotReady   <none>          2m57s   v1.26.1
node2    NotReady   <none>          67s     v1.26.1

# kubectl describe node k8s-node1
Conditions:
...
KubeletNotReady              container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin r

```

</br>
</br>

### 5. Install Helm
```shell
wget https://get.helm.sh/helm-v3.12.2-linux-amd64.tar.gz


tar -xvf helm-v3.12.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin


rm helm-v3.12.2-linux-amd64.tar.gz
rm -rf linux-amd64


helm version
```

Link: 
1. [Helm github](https://github.com/helm/helm/releases)



</br>
</br>

### 6. Install Cilium CNI

```shell
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.13.4 --namespace kube-system
NAME: cilium
LAST DEPLOYED: Tue Jul 18 16:48:51 2023
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble.

Your release version is 1.13.4.
...
```


Link:
1. [Cilium kubeadm](https://docs.cilium.io/en/stable/installation/k8s-install-kubeadm/)





</br>
</br>

### 7. Validate the Installation using Cilium CLI

```shell
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}


cilium status --wait
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment             cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
Containers:            cilium             Running: 3
                       cilium-operator    Running: 2
Cluster Pods:          6/6 managed by Cilium
Helm chart version:    1.13.4
Image versions         cilium             quay.io/cilium/cilium:v1.13.4@sha256:bde8800d61aaad8b8451b10e247ac7bdeb7af187bb698f83d40ad75a38c1ee6b: 3
                       cilium-operator    quay.io/cilium/operator-generic:v1.13.4@sha256:09ab77d324ef4d31f7d341f97ec5a2a4860910076046d57a2d61494d426c6301: 2


```

</br>
</br>

### 8. Verify Installation
```shell
kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   29m   v1.26.1
node1    Ready    <none>          25m   v1.26.1
node2    Ready    <none>          25m   v1.26.1


kubectl get nodes --show-labels
kubectl label node node1 node-role.kubernetes.io/node1=worker

# should you want to unlabel
kubectl label node node1  node-role.kubernetes.io/k8s-node1-							
node/node1 unlabeled


kubectl label node node1 node-role.kubernetes.io/node1=worker
node/node1 labeled

kubectl label node node2 node-role.kubernetes.io/node2=worker
node/node2 labeled

kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   35m   v1.26.1
node1    Ready    node1           31m   v1.26.1
node2    Ready    node2           31m   v1.26.1


# You verify all the cluster component health statuses using the following command:

kubectl get --raw='/readyz?verbose'
kubectl get componentstatus


# sometimes, we might need to run "systemctl restart kubelet" to get the nodes to "Ready" status. with Calico, I experienced it. with Cilium, I never did.



# Deploy A Sample Nginx Application:

cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80 
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector: 
    app: nginx
  type: NodePort  
  ports:
    - port: 80
      targetPort: 80
      nodePort: 32000		
EOF


curl -s http://192.168.1.71:32000/



 k get svc
NAME            TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
kubernetes      ClusterIP   10.64.0.1     <none>        443/TCP        105m
nginx-service   NodePort    10.64.8.171   <none>        80:32000/TCP   29s

 k get deploy -o wide
NAME               READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
nginx-deployment   2/2     2            2           43s   nginx        nginx:latest   app=nginx

k get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
nginx-deployment-6b7f675859-rcrq9   1/1     Running   0          54s   10.244.2.15   node2   <none>           <none>
nginx-deployment-6b7f675859-v6ccf   1/1     Running   0          54s   10.244.1.6    node1   <none>           <none>


```


</br>
</br>

### 9. Setup environments where you will be running kubectl commands
```shell
$ sudo dnf install -y bash-completion

# CREATING AN ALIAS

~/.bash_profile:

echo "alias k=kubectl" >> ~/.bash_profile
echo "source <(kubectl completion bash)" >> ~/.bash_profile
echo "source <(kubectl completion bash | sed s/kubectl/k/g)" >> ~/.bash_profile
. .bash_profile

$ k get nodes
NAME         STATUS   ROLES           AGE     VERSION
k8s-master   Ready    control-plane   7h19m   v1.27.3
k8s-node1    Ready    <none>          7h10m   v1.27.3
k8s-node2    Ready    <none>          7h10m   v1.27.3

```

</br>
</br>

### 10. Install Kubernetes Metrics Server
see monitoring.txt

</br>
</br>

### 11. Stopping and Starting  the Kubernetes cluster
To stop the cluster:
1. As the root user, enter the following command to stop the Kubernetes worker nodes:

shutdown -h now

2. Stop all worker nodes, simultaneously or individually.
3. After all the worker nodes are shut down, shut down the Kubernetes master node.



Starting the Kubernetes cluster
To restart the cluster:

1. Start the server or virtual machine that is running the Docker registry first. This will automatically start the Docker registry. The Docker registry is normally running on the Kubernetes Master node and
   will get started when Master node is started.
2. Start the NFS server and wait two minutes after the operating system has started. The NFS server is normally on the Kubernetes Master Node.
3. Start all worker nodes either simultaneously or individually. If the NFS server is on a dedicated host (not the Kubernetes master node), start the Kubernetes master at the same time you start the worker
  nodes.


Links: 
1. https://www.ibm.com/docs/en/fci/1.0.2?topic=SSCKRH_1.0.2/platform/t_start_stop_kube_cluster.htm
2. https://www.kubesphere.io/docs/v3.3/cluster-administration/shut-down-and-restart-cluster-gracefully/



</br>
</br>

### 12. Clean up or Restart installation:

```shell
# MASTER NODE
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl drain master --delete-emptydir-data --force --ignore-daemonsets

kubeadm reset && rm -rf /etc/cni/net.d
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
ipvsadm -C


# WORKER NODES
kubeadm reset && rm -rf /etc/cni/net.d
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
ipvsadm -C
```


References:
1. https://coredns.io/plugins/loop/#troubleshooting
2. https://stackoverflow.com/questions/62842899/readiness-probe-failed-get-http-10-244-0-38181-ready-dial-tcp-10-244-0-381
3. https://github.com/flannel-io/flannel#deploying-flannel-manually
4. https://docs.docker.com/engine/install/centos/
5. https://github.com/containerd/containerd/blob/main/docs/getting-started.md
