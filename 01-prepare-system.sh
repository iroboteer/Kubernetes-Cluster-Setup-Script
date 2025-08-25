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
if systemctl list-unit-files | grep -q firewalld; then
    systemctl stop firewalld 2>/dev/null || echo "firewalld服务未运行"
    systemctl disable firewalld 2>/dev/null || echo "firewalld服务未启用"
    echo "防火墙已关闭"
else
    echo "firewalld服务未安装"
fi

# 2. 禁用SELinux
echo "2. 禁用SELinux..."
# 检查SELinux状态并安全地禁用它
if command -v setenforce &> /dev/null; then
    setenforce 0 2>/dev/null || echo "SELinux已经是禁用状态或无法设置"
else
    echo "setenforce命令不可用，SELinux可能未安装"
fi

# 修改SELinux配置文件
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
    echo "SELinux配置已更新为permissive模式"
else
    echo "SELinux配置文件不存在"
fi

# 3. 关闭swap
echo "3. 关闭swap..."
if swapon --show | grep -q .; then
    swapoff -a
    echo "已关闭所有swap分区"
else
    echo "没有活动的swap分区"
fi

# 注释掉fstab中的swap条目
if [ -f /etc/fstab ]; then
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "已注释掉fstab中的swap条目"
else
    echo "fstab文件不存在"
fi

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
# 检查Docker是否已安装
if command -v docker &> /dev/null; then
    echo "Docker已安装: $(docker --version)"
else
    echo "安装Docker..."
    yum install -y yum-utils
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# 启动Docker
echo "启动Docker服务..."
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# 验证Docker是否正常运行
if systemctl is-active --quiet docker; then
    echo "Docker服务已启动"
else
    echo "警告: Docker服务启动失败"
    systemctl status docker --no-pager -l
fi

# 8. 安装kubeadm, kubelet, kubectl
echo "8. 安装Kubernetes组件..."
# 检查Kubernetes组件是否已安装
if command -v kubeadm &> /dev/null && command -v kubectl &> /dev/null && command -v kubelet &> /dev/null; then
    echo "Kubernetes组件已安装:"
    echo "  kubeadm: $(kubeadm version --short)"
    echo "  kubectl: $(kubectl version --client --short)"
    echo "  kubelet: $(kubelet --version)"
else
    echo "安装Kubernetes组件..."
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
fi

# 启用kubelet
echo "启用kubelet服务..."
systemctl enable kubelet

echo "Kubernetes组件安装完成"

echo "=========================================="
echo "系统环境准备完成！"
echo "=========================================="
echo "请确保所有节点都运行了此脚本"
echo "然后运行 02-install-control-plane.sh 安装控制平面"
