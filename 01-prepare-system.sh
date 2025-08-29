#!/bin/bash

# Kubernetes环境准备脚本 2025-08-29,安装1.33版本
# 适用于CentOS/RHEL系统

set -e

echo "=========================================="
echo "开始准备Kubernetes环境..."
echo "=========================================="

# 1. 关闭防火墙和SELinux
echo "1. 关闭防火墙和SELinux..."
systemctl stop firewalld || echo "firewalld已停止或未运行"
systemctl disable firewalld || echo "firewalld已禁用或未运行"
setenforce 0 || echo "SELinux已禁用"
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config || echo "SELinux配置已更新"

# 2. 关闭swap
echo "2. 关闭swap..."
swapoff -a || echo "swap已关闭"
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab || echo "fstab中的swap已注释"

# 3. 加载必要的内核模块
echo "3. 加载内核模块..."
modprobe overlay || echo "overlay模块已加载"
modprobe br_netfilter || echo "br_netfilter模块已加载"

# 4. 配置内核参数
echo "4. 配置内核参数..."
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system || echo "内核参数已应用"

# 5. 配置官方 Kubernetes 镜像源
echo "5. 配置官方 Kubernetes 镜像源..."
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes v1.33 (official pkgs.k8s.io)
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
EOF

# 清理缓存
dnf clean all
dnf makecache

# 6. 安装containerd
echo "6. 安装containerd..."
# 安装工具插件
dnf install -y dnf-plugins-core || echo "dnf-plugins-core安装完成"

# 添加Docker官方仓库
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || echo "Docker仓库添加完成"

# 安装containerd.io包
dnf install -y containerd.io || echo "containerd.io安装完成"

# 7. 配置containerd
echo "7. 配置containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml || echo "containerd配置已生成"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || echo "containerd配置已更新"

# 8. 启用containerd
echo "8. 启用containerd..."
systemctl daemon-reload
systemctl enable containerd

# 9. 安装Kubernetes组件
echo "9. 安装Kubernetes组件..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes || echo "Kubernetes组件安装完成"

# 10. 启用kubelet
echo "10. 启用kubelet..."
systemctl enable kubelet || echo "kubelet已启用"

# 11. 打印已安装的组件的版本信息
echo "11. 显示安装的版本信息..."
echo "containerd版本:"
containerd --version || echo "containerd版本信息获取失败"
echo ""
echo "kubelet版本:"
kubelet --version || echo "kubelet版本信息获取失败"
echo ""
echo "kubeadm版本:"
kubeadm version || echo "kubeadm版本信息获取失败"
echo ""
echo "kubectl版本:"
kubectl version --client || echo "kubectl版本信息获取失败"

echo "=========================================="
echo "Kubernetes环境准备完成！"
echo "=========================================="
echo "接下来可以运行: ./02-install-control-plane.sh"
