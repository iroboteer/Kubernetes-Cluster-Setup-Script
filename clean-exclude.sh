#!/bin/bash

# 清理yum exclude配置的脚本

echo "=========================================="
echo "清理yum exclude配置"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "正在清理yum exclude配置..."

# 1. 检查当前的exclude配置
echo "1. 检查当前的exclude配置..."
echo "检查/etc/yum.conf:"
grep -i exclude /etc/yum.conf 2>/dev/null || echo "  无exclude配置"

echo "检查/etc/yum.repos.d/:"
for repo in /etc/yum.repos.d/*.repo; do
    if [ -f "$repo" ]; then
        echo "检查 $repo:"
        grep -i exclude "$repo" 2>/dev/null || echo "  无exclude配置"
    fi
done

# 2. 清理exclude配置
echo ""
echo "2. 清理exclude配置..."

# 清理/etc/yum.conf中的exclude
if grep -q "exclude.*kube" /etc/yum.conf 2>/dev/null; then
    echo "清理/etc/yum.conf中的exclude配置..."
    sed -i '/exclude.*kube/d' /etc/yum.conf
fi

# 清理所有repo文件中的exclude
echo "清理repo文件中的exclude配置..."
for repo in /etc/yum.repos.d/*.repo; do
    if [ -f "$repo" ]; then
        if grep -q "exclude.*kube" "$repo" 2>/dev/null; then
            echo "清理 $repo 中的exclude配置..."
            sed -i '/exclude.*kube/d' "$repo"
        fi
    fi
done

# 3. 清理yum缓存
echo ""
echo "3. 清理yum缓存..."
yum clean all
yum makecache

# 4. 验证清理结果
echo ""
echo "4. 验证清理结果..."
echo "检查/etc/yum.conf:"
grep -i exclude /etc/yum.conf 2>/dev/null || echo "  ✓ 无exclude配置"

echo "检查/etc/yum.repos.d/:"
for repo in /etc/yum.repos.d/*.repo; do
    if [ -f "$repo" ]; then
        echo "检查 $repo:"
        grep -i exclude "$repo" 2>/dev/null || echo "  ✓ 无exclude配置"
    fi
done

# 5. 测试Kubernetes组件安装
echo ""
echo "5. 测试Kubernetes组件安装..."
echo "尝试安装kubelet..."
if yum install -y kubelet --dry-run; then
    echo "✓ kubelet可以安装"
else
    echo "✗ kubelet安装失败"
fi

echo "尝试安装kubeadm..."
if yum install -y kubeadm --dry-run; then
    echo "✓ kubeadm可以安装"
else
    echo "✗ kubeadm安装失败"
fi

echo "尝试安装kubectl..."
if yum install -y kubectl --dry-run; then
    echo "✓ kubectl可以安装"
else
    echo "✗ kubectl安装失败"
fi

echo ""
echo "=========================================="
echo "清理完成！"
echo "=========================================="
echo ""
echo "现在可以尝试安装Kubernetes组件:"
echo "yum install -y kubelet kubeadm kubectl"
echo ""
echo "或者运行修复脚本:"
echo "./fix-k8s-install.sh"
