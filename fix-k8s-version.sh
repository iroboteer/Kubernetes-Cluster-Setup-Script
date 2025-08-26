#!/bin/bash

# 修复Kubernetes版本兼容性问题

echo "=========================================="
echo "修复Kubernetes版本兼容性问题"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "检查当前Kubernetes组件版本..."

# 检查kubeadm版本
if command -v kubeadm &> /dev/null; then
    KUBEADM_VERSION=$(kubeadm version --short 2>/dev/null | sed 's/v//')
    echo "当前kubeadm版本: $KUBEADM_VERSION"
else
    echo "✗ kubeadm未找到"
    exit 1
fi

# 检查kubectl版本
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | sed 's/Client Version: v//')
    echo "当前kubectl版本: $KUBECTL_VERSION"
else
    echo "✗ kubectl未找到"
    exit 1
fi

# 检查kubelet版本
if command -v kubelet &> /dev/null; then
    KUBELET_VERSION=$(kubelet --version 2>/dev/null | sed 's/Kubernetes v//')
    echo "当前kubelet版本: $KUBELET_VERSION"
else
    echo "✗ kubelet未找到"
    exit 1
fi

echo ""
echo "分析版本兼容性..."

# 提取主版本号
KUBEADM_MAJOR=$(echo $KUBEADM_VERSION | cut -d. -f1)
KUBEADM_MINOR=$(echo $KUBEADM_VERSION | cut -d. -f2)

echo "kubeadm主版本: $KUBEADM_MAJOR.$KUBEADM_MINOR"

# 确定兼容的Kubernetes版本
COMPATIBLE_VERSION="v1.33.4"
echo "✓ 使用指定版本: $COMPATIBLE_VERSION"

echo ""
echo "修复配置文件..."

# 备份原始配置文件
if [ -f "kubeadm-config.yaml" ]; then
    cp kubeadm-config.yaml kubeadm-config.yaml.backup
    echo "✓ 已备份原始配置文件: kubeadm-config.yaml.backup"
fi

# 更新配置文件中的版本
if [ -f "kubeadm-config.yaml" ]; then
    # 更新Kubernetes版本
    sed -i "s/kubernetesVersion: v[0-9]\+\.[0-9]\+\.[0-9]\+/kubernetesVersion: $COMPATIBLE_VERSION/" kubeadm-config.yaml
    
    # 更新API版本（如果需要）
    if [ "$KUBEADM_MAJOR" -ge 1 ] && [ "$KUBEADM_MINOR" -ge 32 ]; then
        # 对于较新版本，使用更新的API版本
        sed -i 's/apiVersion: kubeadm.k8s.io\/v1beta3/apiVersion: kubeadm.k8s.io\/v1beta4/' kubeadm-config.yaml
        echo "✓ 已更新API版本到 v1beta4"
    fi
    
    echo "✓ 已更新配置文件中的Kubernetes版本为: $COMPATIBLE_VERSION"
else
    echo "⚠️ 未找到kubeadm-config.yaml文件，将创建新的配置文件"
fi

echo ""
echo "检查并更新安装脚本..."

# 更新02-install-control-plane.sh中的版本
if [ -f "02-install-control-plane.sh" ]; then
    # 备份原始脚本
    cp 02-install-control-plane.sh 02-install-control-plane.sh.backup
    echo "✓ 已备份原始脚本: 02-install-control-plane.sh.backup"
    
    # 更新脚本中的版本
    sed -i "s/kubernetesVersion: v[0-9]\+\.[0-9]\+\.[0-9]\+/kubernetesVersion: $COMPATIBLE_VERSION/" 02-install-control-plane.sh
    
    # 更新API版本（如果需要）
    if [ "$KUBEADM_MAJOR" -ge 1 ] && [ "$KUBEADM_MINOR" -ge 32 ]; then
        sed -i 's/apiVersion: kubeadm.k8s.io\/v1beta3/apiVersion: kubeadm.k8s.io\/v1beta4/' 02-install-control-plane.sh
        echo "✓ 已更新脚本中的API版本到 v1beta4"
    fi
    
    echo "✓ 已更新安装脚本中的Kubernetes版本为: $COMPATIBLE_VERSION"
fi

echo ""
echo "检查是否需要升级Kubernetes组件..."

# 检查是否需要升级组件
CURRENT_MAJOR=$(echo $KUBELET_VERSION | cut -d. -f1)
CURRENT_MINOR=$(echo $KUBELET_VERSION | cut -d. -f2)
TARGET_MAJOR=$(echo $COMPATIBLE_VERSION | cut -d. -f2)
TARGET_MINOR=$(echo $COMPATIBLE_VERSION | cut -d. -f3)

if [ "$CURRENT_MAJOR" -eq 1 ] && [ "$CURRENT_MINOR" -lt "$TARGET_MINOR" ]; then
    echo "⚠️ 检测到版本不匹配，建议升级Kubernetes组件"
    echo "当前版本: $KUBELET_VERSION"
    echo "目标版本: $COMPATIBLE_VERSION"
    
    read -p "是否要升级Kubernetes组件到 $COMPATIBLE_VERSION? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "开始升级Kubernetes组件..."
        
        # 创建临时目录
        mkdir -p /tmp/k8s-upgrade
        cd /tmp/k8s-upgrade
        
        # 配置阿里云Kubernetes源
        echo "配置阿里云Kubernetes源..."
        cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

        # 清理并重建缓存
        dnf clean all
        dnf makecache
        
        # 尝试通过阿里云源安装
        echo "尝试通过阿里云源安装 $COMPATIBLE_VERSION 版本..."
        if dnf install -y kubelet-${COMPATIBLE_VERSION#v} kubeadm-${COMPATIBLE_VERSION#v} kubectl-${COMPATIBLE_VERSION#v}; then
            echo "✓ 通过阿里云源安装成功"
        else
            echo "阿里云源安装失败，使用备用下载方法..."
            
            # 备用方法：直接下载二进制文件
            echo "下载 $COMPATIBLE_VERSION 版本的Kubernetes组件..."
            
            echo "下载kubeadm..."
            curl -LO "https://dl.k8s.io/release/${COMPATIBLE_VERSION}/bin/linux/amd64/kubeadm"
            chmod +x kubeadm
            mv kubeadm /usr/local/bin/
            
            echo "下载kubectl..."
            curl -LO "https://dl.k8s.io/release/${COMPATIBLE_VERSION}/bin/linux/amd64/kubectl"
            chmod +x kubectl
            mv kubectl /usr/local/bin/
            
            echo "下载kubelet..."
            curl -LO "https://dl.k8s.io/release/${COMPATIBLE_VERSION}/bin/linux/amd64/kubelet"
            chmod +x kubelet
            mv kubelet /usr/local/bin/
        fi
        
        # 清理临时目录
        cd /
        rm -rf /tmp/k8s-upgrade
        
        echo "✓ Kubernetes组件已升级到 $COMPATIBLE_VERSION"
        
        # 重新加载systemd配置
        systemctl daemon-reload
        
        # 重启kubelet服务
        if systemctl is-active --quiet kubelet; then
            systemctl restart kubelet
            echo "✓ kubelet服务已重启"
        fi
    else
        echo "跳过组件升级"
    fi
else
    echo "✓ Kubernetes组件版本兼容"
fi

echo ""
echo "=========================================="
echo "版本兼容性修复完成！"
echo "=========================================="
echo ""
echo "修复内容:"
echo "- 兼容的Kubernetes版本: $COMPATIBLE_VERSION"
echo "- 配置文件已更新"
echo "- 安装脚本已更新"
echo ""
echo "现在可以重新运行控制平面安装:"
echo "./02-install-control-plane.sh"
echo ""
echo "或者直接使用修复后的配置:"
echo "kubeadm init --config=kubeadm-config.yaml --upload-certs"
