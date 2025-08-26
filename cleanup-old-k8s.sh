#!/bin/bash

# 清理旧版本Kubernetes环境

echo "=========================================="
echo "清理旧版本Kubernetes环境"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "开始检测和清理旧版本Kubernetes环境..."

# 1. 检查是否有运行的Kubernetes集群
echo "1. 检查运行中的Kubernetes集群..."

if command -v kubectl &> /dev/null; then
    if kubectl get nodes &> /dev/null; then
        echo "⚠️ 检测到运行中的Kubernetes集群"
        echo "集群节点:"
        kubectl get nodes
        echo ""
        read -p "是否要重置集群? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "重置Kubernetes集群..."
            kubeadm reset -f
            echo "✓ 集群已重置"
        else
            echo "跳过集群重置"
        fi
    else
        echo "✓ 未检测到运行中的集群"
    fi
else
    echo "✓ kubectl未安装，跳过集群检查"
fi

# 2. 停止和禁用kubelet服务
echo ""
echo "2. 停止和禁用kubelet服务..."
if systemctl is-active --quiet kubelet; then
    echo "停止kubelet服务..."
    systemctl stop kubelet
    echo "✓ kubelet服务已停止"
fi

if systemctl is-enabled --quiet kubelet; then
    echo "禁用kubelet服务..."
    systemctl disable kubelet
    echo "✓ kubelet服务已禁用"
fi

# 3. 卸载Kubernetes组件包
echo ""
echo "3. 卸载Kubernetes组件包..."

# 检查并卸载通过包管理器安装的组件
if command -v dnf &> /dev/null; then
    echo "检查dnf安装的Kubernetes组件..."
    
    # 卸载kubelet
    if dnf list installed | grep -q kubelet; then
        echo "卸载kubelet..."
        dnf remove -y kubelet
        echo "✓ kubelet已卸载"
    fi
    
    # 卸载kubeadm
    if dnf list installed | grep -q kubeadm; then
        echo "卸载kubeadm..."
        dnf remove -y kubeadm
        echo "✓ kubeadm已卸载"
    fi
    
    # 卸载kubectl
    if dnf list installed | grep -q kubectl; then
        echo "卸载kubectl..."
        dnf remove -y kubectl
        echo "✓ kubectl已卸载"
    fi
fi

if command -v yum &> /dev/null; then
    echo "检查yum安装的Kubernetes组件..."
    
    # 卸载kubelet
    if yum list installed | grep -q kubelet; then
        echo "卸载kubelet..."
        yum remove -y kubelet
        echo "✓ kubelet已卸载"
    fi
    
    # 卸载kubeadm
    if yum list installed | grep -q kubeadm; then
        echo "卸载kubeadm..."
        yum remove -y kubeadm
        echo "✓ kubeadm已卸载"
    fi
    
    # 卸载kubectl
    if yum list installed | grep -q kubectl; then
        echo "卸载kubectl..."
        yum remove -y kubectl
        echo "✓ kubectl已卸载"
    fi
fi

# 4. 删除二进制文件
echo ""
echo "4. 删除Kubernetes二进制文件..."

# 删除常见路径中的二进制文件
for binary in kubeadm kubectl kubelet; do
    for path in /usr/bin /usr/local/bin /opt /usr/sbin; do
        if [ -f "$path/$binary" ]; then
            echo "删除 $path/$binary"
            rm -f "$path/$binary"
        fi
    done
done

echo "✓ 二进制文件清理完成"

# 5. 清理Kubernetes配置目录
echo ""
echo "5. 清理Kubernetes配置目录..."

# 清理/etc/kubernetes目录
if [ -d "/etc/kubernetes" ]; then
    echo "清理 /etc/kubernetes 目录..."
    rm -rf /etc/kubernetes/*
    echo "✓ /etc/kubernetes 目录已清理"
fi

# 清理/var/lib/kubelet目录
if [ -d "/var/lib/kubelet" ]; then
    echo "清理 /var/lib/kubelet 目录..."
    rm -rf /var/lib/kubelet/*
    echo "✓ /var/lib/kubelet 目录已清理"
fi

# 清理/var/lib/etcd目录
if [ -d "/var/lib/etcd" ]; then
    echo "清理 /var/lib/etcd 目录..."
    rm -rf /var/lib/etcd/*
    echo "✓ /var/lib/etcd 目录已清理"
fi

# 清理~/.kube目录
if [ -d "$HOME/.kube" ]; then
    echo "清理 $HOME/.kube 目录..."
    rm -rf $HOME/.kube
    echo "✓ $HOME/.kube 目录已清理"
fi

# 6. 清理systemd服务文件
echo ""
echo "6. 清理systemd服务文件..."

# 删除kubelet服务文件
if [ -f "/etc/systemd/system/kubelet.service" ]; then
    echo "删除kubelet服务文件..."
    rm -f /etc/systemd/system/kubelet.service
    echo "✓ kubelet服务文件已删除"
fi

if [ -f "/usr/lib/systemd/system/kubelet.service" ]; then
    echo "删除系统kubelet服务文件..."
    rm -f /usr/lib/systemd/system/kubelet.service
    echo "✓ 系统kubelet服务文件已删除"
fi

# 重新加载systemd配置
systemctl daemon-reload

# 7. 清理网络配置
echo ""
echo "7. 清理网络配置..."

# 清理iptables规则
echo "清理iptables规则..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
echo "✓ iptables规则已清理"

# 清理IPVS规则
if command -v ipvsadm &> /dev/null; then
    echo "清理IPVS规则..."
    ipvsadm -C
    echo "✓ IPVS规则已清理"
fi

# 8. 清理containerd中的Kubernetes镜像
echo ""
echo "8. 清理containerd中的Kubernetes镜像..."

if command -v ctr &> /dev/null; then
    echo "清理Kubernetes相关镜像..."
    ctr -n k8s.io images ls | grep -E "(k8s|kubernetes)" | awk '{print $1}' | xargs -r ctr -n k8s.io images rm
    echo "✓ Kubernetes镜像已清理"
fi

# 9. 清理临时文件
echo ""
echo "9. 清理临时文件..."

# 清理当前目录中的Kubernetes相关文件
if [ -f "kubeadm-config.yaml" ]; then
    echo "删除kubeadm配置文件..."
    rm -f kubeadm-config.yaml
fi

if [ -f "tigera-operator.yaml" ]; then
    echo "删除Calico配置文件..."
    rm -f tigera-operator.yaml
fi

if [ -f "calico-custom-resources.yaml" ]; then
    echo "删除Calico自定义资源配置文件..."
    rm -f calico-custom-resources.yaml
fi

echo "✓ 临时文件清理完成"

# 10. 清理环境变量
echo ""
echo "10. 清理环境变量..."

# 从/etc/profile中移除KUBECONFIG设置
if grep -q "KUBECONFIG" /etc/profile; then
    echo "清理KUBECONFIG环境变量..."
    sed -i '/export KUBECONFIG/d' /etc/profile
    echo "✓ KUBECONFIG环境变量已清理"
fi

# 从/etc/profile中移除Kubernetes PATH设置
if grep -q "kube" /etc/profile; then
    echo "清理Kubernetes PATH设置..."
    sed -i '/export PATH.*kube/d' /etc/profile
    echo "✓ Kubernetes PATH设置已清理"
fi

echo ""
echo "=========================================="
echo "旧版本Kubernetes环境清理完成！"
echo "=========================================="
echo ""
echo "清理内容:"
echo "- 停止并禁用kubelet服务"
echo "- 卸载Kubernetes组件包"
echo "- 删除二进制文件"
echo "- 清理配置目录"
echo "- 清理systemd服务文件"
echo "- 清理网络配置"
echo "- 清理containerd镜像"
echo "- 清理临时文件"
echo "- 清理环境变量"
echo ""
echo "现在可以安全地安装新版本的Kubernetes了！"
