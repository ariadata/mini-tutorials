#!/bin/bash
set -e
cd "$(dirname "$0")" # cd "$(dirname "$0")" || exit

export DEBIAN_FRONTEND=noninteractive

sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
sudo apt -y install wget curl nano lsb-release gnupg2 apt-transport-https ca-certificates software-properties-common

sudo swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo -e "overlay\nbr_netfilter\n" | sudo tee -a /etc/modules-load.d/containerd.conf
echo -e "net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n" | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf
sudo sysctl --system

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Containerd Using docker repo: https://docs.docker.com/engine/install/ubuntu/
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# apt update && apt install -y containerd.io=1.6.26-1
sudo apt update && sudo apt install -y containerd.io

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo sed -i 's/pause:3.6/pause:3.9/g' /etc/containerd/config.toml

sudo systemctl enable --now containerd && sudo systemctl restart containerd

# apt update && apt install -y kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl
sudo apt update && sudo apt install -y kubelet=1.29.0-1.1 kubeadm=1.29.0-1.1 kubectl=1.29.0-1.1 && apt-mark hold kubelet kubeadm kubectl

read -e -p $'Do you want to \e[31mreboot now\033[0m ? : ' -i "y" if_reboot_at_end
if [[ $if_reboot_at_end =~ ^([Yy])$ ]]
then
	sudo reboot
	exit
fi
