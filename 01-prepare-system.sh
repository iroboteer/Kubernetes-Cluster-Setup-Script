#!/bin/bash

# Kubernetes集群系统准备脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始准备系统环境..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查操作系统版本
if ! grep -q "CentOS Stream release 10" /etc/redhat-release; then
    echo "警告: 此脚本专为CentOS Stream 10设计"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. 关闭防火墙
echo "1. 关闭防火墙..."
systemctl stop firewalld
systemctl disable firewalld

# 2. 禁用SELinux
echo "2. 禁用SELinux..."
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 3. 关闭swap
echo "3. 关闭swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. 配置内核参数
echo "4. 配置内核参数..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 5. 配置阿里云镜像源
echo "5. 配置阿里云镜像源..."
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

# 6. 配置Docker镜像源
echo "6. 配置Docker镜像源..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# 7. 安装Docker
echo "7. 安装Docker..."
yum install -y yum-utils
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动Docker
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# 8. 安装kubeadm, kubelet, kubectl
echo "8. 安装Kubernetes组件..."
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 启用kubelet
systemctl enable kubelet

echo "=========================================="
echo "系统环境准备完成！"
echo "=========================================="
echo "请确保所有节点都运行了此脚本"
echo "然后运行 02-install-control-plane.sh 安装控制平面"
