#!/bin/bash

# 安装Kubernetes 1.33.4版本（使用阿里云源）

echo "=========================================="
echo "安装Kubernetes 1.33.4版本"
echo "使用阿里云镜像源"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

set -e

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

# 查看可用的版本
echo "可用的Kubernetes版本:"
dnf list available kubelet --showduplicates | grep kubelet | tail -10

echo ""
echo "4. 安装Kubernetes 1.33.4组件..."

# 尝试安装指定版本
if dnf install -y kubelet-1.33.4 kubeadm-1.33.4 kubectl-1.33.4; then
    echo "✓ Kubernetes 1.33.4安装成功"
else
    echo "⚠️ 通过yum安装失败，尝试备用方法..."
    
    # 备用方法：直接下载二进制文件
    echo "使用备用安装方法..."
    
    # 创建临时目录
    mkdir -p /tmp/k8s-install
    cd /tmp/k8s-install
    
    K8S_VERSION="v1.33.4"
    
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

echo ""
echo "5. 检查安装结果..."

# 检查各个组件
echo "检查kubeadm:"
if command -v kubeadm &> /dev/null; then
    echo "✓ kubeadm已安装: $(kubeadm version --short)"
else
    echo "✗ kubeadm未找到"
fi

echo "检查kubectl:"
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl已安装: $(kubectl version --client --short)"
else
    echo "✗ kubectl未找到"
fi

echo "检查kubelet:"
if command -v kubelet &> /dev/null; then
    echo "✓ kubelet已安装: $(kubelet --version)"
else
    echo "✗ kubelet未找到"
fi

echo ""
echo "6. 创建kubelet服务单元文件..."

# 检查kubelet服务是否存在
if systemctl list-unit-files | grep -q kubelet; then
    echo "✓ kubelet服务单元文件已存在"
else
    echo "创建kubelet服务单元文件..."
    
    # 创建kubelet服务单元文件
    cat > /etc/systemd/system/kubelet.service << 'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    echo "✓ kubelet服务单元文件已创建"
    
    # 重新加载systemd配置
    systemctl daemon-reload
fi

# 启用kubelet服务
echo "启用kubelet服务..."
systemctl enable kubelet

echo ""
echo "7. 创建必要的目录..."

# 创建必要的目录
mkdir -p /var/lib/kubelet
mkdir -p /etc/kubernetes

echo "✓ 目录创建完成"

echo ""
echo "8. 配置环境变量..."

# 确保PATH正确
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    echo "添加/usr/local/bin到PATH..."
    export PATH="/usr/local/bin:$PATH"
    echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/profile
fi

echo "✓ 环境变量配置完成"

echo ""
echo "=========================================="
echo "Kubernetes 1.33.4安装完成！"
echo "=========================================="
echo ""
echo "安装信息:"
echo "- 版本: 1.33.4"
echo "- 镜像源: 阿里云"
echo "- 安装路径: /usr/local/bin"
echo ""
echo "接下来可以运行:"
echo "./02-install-control-plane.sh"
echo ""
echo "或者运行检查脚本:"
echo "./check-k8s-components.sh"
