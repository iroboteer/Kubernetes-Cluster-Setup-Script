#!/bin/bash

# 修复Kubernetes安装问题的脚本

echo "=========================================="
echo "修复Kubernetes安装问题"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "正在修复Kubernetes安装问题..."

# 1. 修复yum源配置
echo "1. 修复yum源配置..."
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

# 2. 清理dnf缓存
echo "2. 清理dnf缓存..."
dnf clean all
dnf makecache

# 3. 检查并安装Kubernetes组件
echo "3. 安装Kubernetes组件..."

# 检查是否已安装
if command -v kubeadm &> /dev/null && command -v kubectl &> /dev/null && command -v kubelet &> /dev/null; then
    echo "Kubernetes组件已安装:"
    echo "  kubeadm: $(kubeadm version --short)"
    echo "  kubectl: $(kubectl version --client --short)"
    echo "  kubelet: $(kubelet --version)"
else
    echo "安装Kubernetes组件..."
    
    # 尝试dnf安装
    echo "尝试dnf安装Kubernetes组件..."
    
    # 检查是否有exclude配置
    if grep -r "exclude.*kube" /etc/yum.repos.d/ /etc/yum.conf 2>/dev/null; then
        echo "发现exclude配置，正在清理..."
        # 清理所有exclude配置
        sed -i '/exclude.*kube/d' /etc/yum.repos.d/*.repo /etc/yum.conf 2>/dev/null || true
        dnf clean all
        dnf makecache
    fi
    
    if dnf install -y kubelet kubeadm kubectl; then
        echo "✓ dnf安装成功"
    else
        echo "dnf安装失败，尝试备用方法..."
        
        # 备用安装方法：直接下载二进制文件
        echo "使用备用安装方法..."
        
        # 创建临时目录
        mkdir -p /tmp/k8s-install
        cd /tmp/k8s-install
        
        # 下载Kubernetes组件
        K8S_VERSION="v1.28.0"
        
        echo "下载kubeadm..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm"
        chmod +x kubeadm
        mv kubeadm /usr/local/bin/
        
        echo "下载kubectl..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl /usr/local/bin/
        
        echo "下载kubelet..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet"
        chmod +x kubelet
        mv kubelet /usr/local/bin/
        
        # 清理临时目录
        cd /
        rm -rf /tmp/k8s-install
        
        echo "✓ 备用安装成功"
    fi
fi

# 4. 检查安装结果
echo "4. 检查安装结果..."
echo "检查kubeadm:"
if command -v kubeadm &> /dev/null; then
    echo "✓ kubeadm已安装: $(kubeadm version --short)"
else
    echo "✗ kubeadm未找到"
    find /usr/bin /usr/local/bin -name kubeadm 2>/dev/null || echo "  在常见路径中未找到"
fi

echo "检查kubectl:"
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl已安装: $(kubectl version --client --short)"
else
    echo "✗ kubectl未找到"
    find /usr/bin /usr/local/bin -name kubectl 2>/dev/null || echo "  在常见路径中未找到"
fi

echo "检查kubelet:"
if command -v kubelet &> /dev/null; then
    echo "✓ kubelet已安装: $(kubelet --version)"
else
    echo "✗ kubelet未找到"
    find /usr/bin /usr/local/bin -name kubelet 2>/dev/null || echo "  在常见路径中未找到"
fi

# 5. 启用kubelet服务
echo "5. 启用kubelet服务..."
systemctl enable kubelet

# 6. 确保PATH正确
echo "6. 确保PATH正确..."
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    echo "添加/usr/local/bin到PATH..."
    export PATH="/usr/local/bin:$PATH"
    echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/profile
fi

if ! echo "$PATH" | grep -q "/usr/bin"; then
    echo "添加/usr/bin到PATH..."
    export PATH="/usr/bin:$PATH"
    echo 'export PATH="/usr/bin:$PATH"' >> /etc/profile
fi

echo ""
echo "=========================================="
echo "修复完成！"
echo "=========================================="
echo ""
echo "现在可以运行:"
echo "./02-install-control-plane.sh"
echo ""
echo "或者运行检查脚本:"
echo "./check-k8s-components.sh"
