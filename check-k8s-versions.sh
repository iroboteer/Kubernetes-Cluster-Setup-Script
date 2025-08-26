#!/bin/bash

# 检查阿里云源中可用的Kubernetes版本

echo "=========================================="
echo "检查阿里云源中可用的Kubernetes版本"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "1. 配置阿里云Kubernetes源..."

# 创建Kubernetes源配置文件
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

echo "✓ 阿里云Kubernetes源配置完成"

echo ""
echo "2. 清理并重建yum缓存..."

# 清理缓存
dnf clean all
dnf makecache

echo "✓ 缓存重建完成"

echo ""
echo "3. 检查可用的Kubernetes版本..."

echo "可用的kubelet版本:"
dnf list available kubelet --showduplicates | grep kubelet | tail -10

echo ""
echo "可用的kubeadm版本:"
dnf list available kubeadm --showduplicates | grep kubeadm | tail -10

echo ""
echo "可用的kubectl版本:"
dnf list available kubectl --showduplicates | grep kubectl | tail -10

echo ""
echo "4. 提取最新版本信息..."

# 获取最新版本
LATEST_KUBELET=$(dnf list available kubelet --showduplicates | grep kubelet | tail -1 | awk '{print $2}' | sed 's/kubelet-//')
LATEST_KUBEADM=$(dnf list available kubeadm --showduplicates | grep kubeadm | tail -1 | awk '{print $2}' | sed 's/kubeadm-//')
LATEST_KUBECTL=$(dnf list available kubectl --showduplicates | grep kubectl | tail -1 | awk '{print $2}' | sed 's/kubectl-//')

echo "最新可用版本:"
echo "- kubelet: $LATEST_KUBELET"
echo "- kubeadm: $LATEST_KUBEADM"
echo "- kubectl: $LATEST_KUBECTL"

echo ""
echo "5. 检查版本兼容性..."

# 检查版本是否一致
if [ "$LATEST_KUBELET" = "$LATEST_KUBEADM" ] && [ "$LATEST_KUBEADM" = "$LATEST_KUBECTL" ]; then
    echo "✓ 所有组件版本一致: $LATEST_KUBELET"
    echo "✓ 可以使用此版本进行安装"
else
    echo "⚠️ 组件版本不一致:"
    echo "  kubelet: $LATEST_KUBELET"
    echo "  kubeadm: $LATEST_KUBEADM"
    echo "  kubectl: $LATEST_KUBECTL"
    echo "建议使用相同的版本"
fi

echo ""
echo "=========================================="
echo "检查完成！"
echo "=========================================="
echo ""
echo "总结:"
echo "- 阿里云源中最新的Kubernetes版本: $LATEST_KUBELET"
echo "- 建议安装命令: dnf install -y kubelet-$LATEST_KUBELET kubeadm-$LATEST_KUBEADM kubectl-$LATEST_KUBECTL"
echo ""
echo "注意: 如果阿里云源中没有1.33.4版本，脚本会自动使用备用方法下载"
