#!/bin/bash

# Kubernetes一键清除脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始清除Kubernetes集群..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 确认清除操作
echo "警告: 此操作将完全清除Kubernetes集群和所有相关数据"
echo "包括:"
echo "- 所有Kubernetes Pod、Service、Deployment等资源"
echo "- 所有容器和镜像"
echo "- Kubernetes配置文件"
echo "- 网络配置"
echo ""
read -p "确认要清除Kubernetes集群吗? (输入 'YES' 确认): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "操作已取消"
    exit 1
fi

echo "开始清除Kubernetes集群..."

# 1. 重置kubeadm（如果存在）
echo "1. 重置kubeadm..."
if command -v kubeadm &> /dev/null; then
    kubeadm reset -f
fi

# 2. 停止并禁用kubelet
echo "2. 停止kubelet服务..."
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

# 3. 停止并禁用Docker
echo "3. 停止Docker服务..."
systemctl stop docker 2>/dev/null || true
systemctl disable docker 2>/dev/null || true

# 4. 删除Kubernetes相关目录和文件
echo "4. 删除Kubernetes相关文件..."
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/
rm -rf ~/.kube/
rm -rf /var/lib/cni/
rm -rf /etc/cni/
rm -rf /opt/cni/

# 5. 删除Docker相关数据
echo "5. 删除Docker相关数据..."
rm -rf /var/lib/docker/
rm -rf /var/run/docker.sock

# 6. 删除containerd数据
echo "6. 删除containerd数据..."
rm -rf /var/lib/containerd/
rm -rf /run/containerd/

# 7. 清理网络接口
echo "7. 清理网络接口..."
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete docker0 2>/dev/null || true

# 8. 清理iptables规则
echo "8. 清理iptables规则..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# 9. 卸载Kubernetes包
echo "9. 卸载Kubernetes包..."
dnf remove -y kubeadm kubelet kubectl kubernetes-cni 2>/dev/null || true

# 10. 卸载Docker包
echo "10. 卸载Docker包..."
dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

# 11. 清理dnf缓存
echo "11. 清理dnf缓存..."
dnf clean all

# 12. 删除Kubernetes dnf源
echo "12. 删除Kubernetes dnf源..."
rm -f /etc/yum.repos.d/kubernetes.repo

# 13. 删除Docker dnf源
echo "13. 删除Docker dnf源..."
rm -f /etc/yum.repos.d/docker-ce.repo

# 14. 清理系统日志
echo "14. 清理系统日志..."
journalctl --vacuum-time=1s

# 15. 重启网络服务
echo "15. 重启网络服务..."
systemctl restart network

# 16. 显示清理结果
echo "=========================================="
echo "Kubernetes集群清除完成！"
echo "=========================================="
echo ""
echo "已清除的内容:"
echo "✓ Kubernetes集群配置"
echo "✓ 所有容器和镜像"
echo "✓ 网络配置"
echo "✓ 系统服务"
echo "✓ 相关软件包"
echo ""
echo "系统已恢复到安装Kubernetes之前的状态"
echo ""
echo "如果需要重新安装Kubernetes，请运行:"
echo "./01-prepare-system.sh"
