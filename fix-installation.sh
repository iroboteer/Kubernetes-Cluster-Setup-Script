#!/bin/bash

# Kubernetes安装问题修复脚本
# 适用于CentOS Stream 10

echo "=========================================="
echo "Kubernetes安装问题修复脚本"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "检查系统状态..."

# 检查操作系统
echo "1. 检查操作系统版本..."
if grep -q "CentOS Stream release 10" /etc/redhat-release; then
    echo "✓ 操作系统: CentOS Stream 10"
else
    echo "⚠ 警告: 此脚本专为CentOS Stream 10设计"
    echo "当前系统: $(cat /etc/redhat-release)"
fi

# 检查kubeadm
echo ""
echo "2. 检查Kubernetes组件..."
if command -v kubeadm &> /dev/null; then
    echo "✓ kubeadm已安装: $(kubeadm version --short)"
else
    echo "✗ kubeadm未安装"
    echo "需要运行: ./01-prepare-system.sh"
fi

if command -v kubectl &> /dev/null; then
    echo "✓ kubectl已安装: $(kubectl version --client --short)"
else
    echo "✗ kubectl未安装"
    echo "需要运行: ./01-prepare-system.sh"
fi

if command -v kubelet &> /dev/null; then
    echo "✓ kubelet已安装"
else
    echo "✗ kubelet未安装"
    echo "需要运行: ./01-prepare-system.sh"
fi

# 检查containerd
echo ""
echo "3. 检查containerd..."
if command -v containerd &> /dev/null; then
    echo "✓ containerd已安装: $(containerd --version)"
    if systemctl is-active --quiet containerd; then
        echo "✓ containerd服务正在运行"
    else
        echo "✗ containerd服务未运行"
        echo "尝试启动containerd..."
        systemctl start containerd
        systemctl enable containerd
    fi
else
    echo "✗ containerd未安装"
    echo "需要运行: ./01-prepare-system.sh"
fi

# 检查集群状态
echo ""
echo "4. 检查集群状态..."
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✓ 控制平面配置文件存在"
    if command -v kubectl &> /dev/null; then
        export KUBECONFIG=/etc/kubernetes/admin.conf
        if kubectl get nodes &> /dev/null; then
            echo "✓ 集群连接正常"
            echo "节点状态:"
            kubectl get nodes
        else
            echo "✗ 无法连接到集群"
        fi
    fi
else
    echo "✗ 控制平面配置文件不存在"
    echo "需要运行: ./02-install-control-plane.sh"
fi

# 检查网络插件
echo ""
echo "5. 检查网络插件..."
if command -v kubectl &> /dev/null && [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get pods -n calico-system &> /dev/null; then
        echo "✓ Calico已安装"
        kubectl get pods -n calico-system
    else
        echo "✗ Calico未安装"
        echo "需要运行: ./03-install-calico.sh"
    fi
fi

# 检查Dashboard
echo ""
echo "6. 检查Dashboard..."
if command -v kubectl &> /dev/null && [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get pods -n kubernetes-dashboard &> /dev/null; then
        echo "✓ Dashboard已安装"
        kubectl get pods -n kubernetes-dashboard
    else
        echo "✗ Dashboard未安装"
        echo "需要运行: ./04-install-dashboard.sh"
    fi
fi

echo ""
echo "=========================================="
echo "修复建议:"
echo "=========================================="

if ! command -v kubeadm &> /dev/null; then
    echo "1. 首先运行系统环境准备:"
    echo "   ./01-prepare-system.sh"
    echo ""
fi

if command -v kubeadm &> /dev/null && [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "2. 然后安装控制平面:"
    echo "   ./02-install-control-plane.sh"
    echo ""
fi

if [ -f /etc/kubernetes/admin.conf ] && ! kubectl get pods -n calico-system &> /dev/null; then
    echo "3. 安装网络插件:"
    echo "   ./03-install-calico.sh"
    echo ""
fi

if [ -f /etc/kubernetes/admin.conf ] && ! kubectl get pods -n kubernetes-dashboard &> /dev/null; then
    echo "4. 安装Dashboard:"
    echo "   ./04-install-dashboard.sh"
    echo ""
fi

echo "或者使用一键安装:"
echo "   ./00-master-install.sh (选择选项6)"
echo ""
echo "=========================================="
