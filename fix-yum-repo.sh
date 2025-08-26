#!/bin/bash

# 修复yum源问题的脚本

echo "=========================================="
echo "修复yum源问题"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "正在修复yum源问题..."

# 1. 备份现有的repo文件
echo "1. 备份现有repo文件..."
mkdir -p /etc/yum.repos.d/backup
cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null || true

# 2. 清理yum缓存
echo "2. 清理yum缓存..."
yum clean all
rm -rf /var/cache/yum/*
rm -rf /var/cache/dnf/*

# 3. 修复Kubernetes repo
echo "3. 修复Kubernetes repo..."
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
exclude=kubelet kubeadm kubectl
EOF

# 4. 配置containerd源
echo "4. 配置containerd源..."
cat > /etc/yum.repos.d/containerd.repo << EOF
[containerd]
name=containerd
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

# 5. 重建dnf缓存
echo "5. 重建dnf缓存..."
dnf makecache

# 6. 测试yum源
echo "6. 测试yum源..."
echo "测试Kubernetes源:"
yum repolist | grep kubernetes || echo "Kubernetes源不可用"

echo "测试containerd源:"
yum repolist | grep containerd || echo "containerd源不可用"

# 7. 尝试安装测试包
echo "7. 测试安装..."
echo "测试安装dnf-utils..."
dnf install -y dnf-utils --nogpgcheck || echo "dnf-utils安装失败"

echo ""
echo "=========================================="
echo "修复完成！"
echo "=========================================="
echo ""
echo "如果还有问题，可以尝试以下备用方案："
echo ""
echo "1. 使用二进制安装Kubernetes:"
echo "   curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubeadm"
echo "   chmod +x kubeadm && mv kubeadm /usr/local/bin/"
echo ""
echo "2. 使用官方containerd安装:"
echo "   dnf install -y containerd.io"
echo ""
echo "3. 重新运行安装脚本:"
echo "   ./01-prepare-system.sh"
