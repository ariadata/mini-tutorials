# Multi-Master k8s 1.29 cluster on ubuntu-22 with containerd

> Kubernetes 1.29.0

> Containerd 1.6.26

> Calico 3.27 CNI

>Ubuntu 22.04

## In this example we have 4 nodes:

> 192.168.3.10 KControl1

> 192.168.3.11 KControl2

> 192.168.3.12 KWorker1

> 192.168.3.13 KWorker2

## Set Hostnames (as sudo user) in `All Nodes` :
```bash
#Control Node1:
sudo hostnamectl --static set-hostname KControl1
#Control Node1:
sudo hostnamectl --static set-hostname KControl2
#Worker Node 1:
sudo hostnamectl --static set-hostname KWorker1
#Worker Node 2:
sudo hostnamectl --static set-hostname KWorker2

# all nodes
sudo sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg

echo -e "192.168.3.10 KControl1\n192.168.3.11 KControl2\n192.168.3.12 KWorker1\n192.168.3.13 KWorker2" | sudo tee -a /etc/hosts
```

## Run Init & installation Script (as sudo user) in `All Nodes` :
```bash
sudo systemctl disable --now systemd-resolved.service

sudo rm -rf /etc/resolv.conf && echo -e "nameserver 1.1.1.1\nnameserver 8.8.4.4\n" | sudo tee /etc/resolv.conf

bash <(curl -sSL https://github.com/ariadata/mini-tutorials/raw/main/devops/kubernetes/1.29/k8s-ubuntu-22.sh)

reboot
```

## Install Control-Plane (as sudo user) in `Control Node` :
```bash
# change the IP address to your control plane IP address
sudo kubeadm init --control-plane-endpoint "192.168.3.10:6443" --upload-certs --kubernetes-version 1.29.0 --pod-network-cidr=10.10.0.0/16
### Note ###
# Save the results (do NOT run in other nodes)
#########

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
bash -l

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

```
## Connect Control-Plane Nodes (as sudo user) in `Master Nodes` :
```bash
#Run the command from the token created above with sudo prefix
sudo $COMMAND$

sudo -i -u ubuntu
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
bash -l
```

## Connect Worker Nodes (as sudo user) in `Worker Nodes` :
```bash
#Run the command from the token create output above
```

## Check Cluster Status (as sudo user) in `Control Node` :
```bash
kubectl get nodes -o wide
```

## Bash Completion (as sudo user) in `Master Nodes` :
```bash
sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo 'complete -F __start_kubectl -k' >> ~/.bashrc
bash -l
```


# Used Links:
- https://hbayraktar.medium.com/how-to-install-kubernetes-cluster-on-ubuntu-22-04-step-by-step-guide-7dbf7e8f5f99
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- https://youtu.be/7k9Rdlx30OY
- https://www.itsgeekhead.com/tuts/kubernetes-126-ubuntu-2204.txt
- https://www.youtube.com/watch?v=Ro2qeYeisZQ
- https://www.youtube.com/watch?v=8q9uPjDF59Q
