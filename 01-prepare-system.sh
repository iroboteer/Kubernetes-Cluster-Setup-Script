#!/bin/bash

# Kubernetes环境准备脚本
# 适用于CentOS/RHEL系统

set -e

echo "=========================================="
echo "开始准备Kubernetes环境..."
echo "=========================================="

# 1. 关闭防火墙和SELinux
echo "1. 关闭防火墙和SELinux..."
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# 2. 关闭swap
echo "2. 关闭swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 3. 加载必要的内核模块
echo "3. 加载内核模块..."
modprobe overlay
modprobe br_netfilter

# 4. 配置内核参数
echo "4. 配置内核参数..."
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# 5. 配置阿里云Kubernetes镜像源
echo "5. 配置阿里云Kubernetes镜像源..."
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# 6. 安装containerd
echo "6. 安装containerd..."
dnf install -y containerd

# 7. 配置containerd
echo "7. 配置containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 8. 启动containerd
echo "8. 启动containerd..."
systemctl daemon-reload
systemctl enable containerd
systemctl start containerd

# 9. 安装Kubernetes组件
echo "9. 安装Kubernetes组件..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 10. 启用kubelet
echo "10. 启用kubelet..."
systemctl enable kubelet

echo "=========================================="
echo "Kubernetes环境准备完成！"
echo "=========================================="
echo "接下来可以运行: ./02-install-control-plane.sh"
