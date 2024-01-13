#!/bin/bash
set -e
cd "$(dirname "$0")" # cd "$(dirname "$0")" || exit

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y && apt autoremove -y
apt -y install wget curl nano lsb-release gnupg2 apt-transport-https ca-certificates software-properties-common

swapoff -a && sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo -e "overlay\nbr_netfilter\n" | tee -a /etc/modules-load.d/containerd.conf
echo -e "net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\n" | tee -a /etc/sysctl.d/99-kubernetes-cri.conf
sysctl --system

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install Containerd Using docker repo: https://docs.docker.com/engine/install/ubuntu/
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# apt update && apt install -y containerd.io=1.6.26-1
apt update && apt install -y containerd.io

containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sed -i 's/pause:3.6/pause:3.9/g' /etc/containerd/config.toml

systemctl enable --now containerd && systemctl restart containerd

# apt update && apt install -y kubelet kubeadm kubectl && apt-mark hold kubelet kubeadm kubectl
apt update && apt install -y kubelet=1.29.0-1.1 kubeadm=1.29.0-1.1 kubectl=1.29.0-1.1 && apt-mark hold kubelet kubeadm kubectl

read -e -p $'Do you want to \e[31mreboot now\033[0m ? : ' -i "y" if_reboot_at_end
if [[ $if_reboot_at_end =~ ^([Yy])$ ]]
then
	reboot
	exit
fi