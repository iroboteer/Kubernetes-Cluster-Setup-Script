#!/bin/bash

# Kubernetes组件检查脚本

echo "=========================================="
echo "检查Kubernetes组件安装状态"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查Kubernetes组件
check_component() {
    local component=$1
    local path=$(which $component 2>/dev/null || find /usr/bin /usr/local/bin /opt -name $component 2>/dev/null | head -1)
    
    if [ -n "$path" ]; then
        echo "✓ $component找到: $path"
        if [ -x "$path" ]; then
            echo "  - 可执行权限: ✓"
            if $component version --short &>/dev/null; then
                echo "  - 版本信息: $($component version --short 2>/dev/null || $component --version 2>/dev/null)"
            else
                echo "  - 版本信息: 无法获取"
            fi
        else
            echo "  - 可执行权限: ✗"
        fi
        return 0
    else
        echo "✗ $component未找到"
        return 1
    fi
}

echo "1. 检查Kubernetes组件..."
echo ""

# 检查各个组件
kubeadm_found=false
kubectl_found=false
kubelet_found=false

if check_component kubeadm; then
    kubeadm_found=true
fi

echo ""
if check_component kubectl; then
    kubectl_found=true
fi

echo ""
if check_component kubelet; then
    kubelet_found=true
fi

echo ""
echo "2. 检查yum包状态..."
echo ""

# 检查yum包
yum list installed | grep -E "(kubeadm|kubectl|kubelet)" || echo "未找到Kubernetes相关包"

echo ""
echo "3. 检查PATH环境变量..."
echo "PATH: $PATH"

echo ""
echo "4. 检查常见安装路径..."
for path in /usr/bin /usr/local/bin /opt /usr/sbin; do
    if [ -d "$path" ]; then
        echo "检查 $path:"
        ls -la $path/kube* 2>/dev/null || echo "  未找到Kubernetes组件"
    fi
done

echo ""
echo "5. 检查服务状态..."
if systemctl list-unit-files | grep -q kubelet; then
    echo "kubelet服务状态:"
    systemctl status kubelet --no-pager -l
else
    echo "kubelet服务未找到"
fi

echo ""
echo "=========================================="
echo "检查结果汇总"
echo "=========================================="

if $kubeadm_found && $kubectl_found && $kubelet_found; then
    echo "✓ 所有Kubernetes组件都已正确安装"
    echo ""
    echo "可以继续安装控制平面:"
    echo "./02-install-control-plane.sh"
else
    echo "✗ 部分Kubernetes组件缺失"
    echo ""
    echo "建议重新运行系统环境准备:"
    echo "./01-prepare-system.sh"
    
    if ! $kubeadm_found; then
        echo "缺失: kubeadm"
    fi
    if ! $kubectl_found; then
        echo "缺失: kubectl"
    fi
    if ! $kubelet_found; then
        echo "缺失: kubelet"
    fi
fi

echo ""
echo "=========================================="
