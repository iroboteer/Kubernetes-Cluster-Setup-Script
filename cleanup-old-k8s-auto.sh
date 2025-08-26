#!/bin/bash

# 自动清理旧版本Kubernetes环境（无交互）

echo "检测和清理旧版本Kubernetes环境..."

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 1. 检查是否有运行的Kubernetes集群
if command -v kubectl &> /dev/null; then
    if kubectl get nodes &> /dev/null; then
        echo "⚠️ 检测到运行中的Kubernetes集群，自动重置..."
        kubeadm reset -f
        echo "✓ 集群已重置"
    fi
fi

# 2. 停止和禁用kubelet服务
if systemctl is-active --quiet kubelet; then
    systemctl stop kubelet
fi

if systemctl is-enabled --quiet kubelet; then
    systemctl disable kubelet
fi

# 3. 卸载Kubernetes组件包
if command -v dnf &> /dev/null; then
    dnf remove -y kubelet kubeadm kubectl 2>/dev/null || true
fi

if command -v yum &> /dev/null; then
    yum remove -y kubelet kubeadm kubectl 2>/dev/null || true
fi

# 4. 删除二进制文件
for binary in kubeadm kubectl kubelet; do
    for path in /usr/bin /usr/local/bin /opt /usr/sbin; do
        rm -f "$path/$binary" 2>/dev/null || true
    done
done

# 5. 清理Kubernetes配置目录
rm -rf /etc/kubernetes/* 2>/dev/null || true
rm -rf /var/lib/kubelet/* 2>/dev/null || true
rm -rf /var/lib/etcd/* 2>/dev/null || true
rm -rf $HOME/.kube 2>/dev/null || true

# 6. 清理systemd服务文件
rm -f /etc/systemd/system/kubelet.service 2>/dev/null || true
rm -f /usr/lib/systemd/system/kubelet.service 2>/dev/null || true
systemctl daemon-reload

# 7. 清理网络配置
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true

if command -v ipvsadm &> /dev/null; then
    ipvsadm -C 2>/dev/null || true
fi

# 8. 清理containerd中的Kubernetes镜像
if command -v ctr &> /dev/null; then
    ctr -n k8s.io images ls | grep -E "(k8s|kubernetes)" | awk '{print $1}' | xargs -r ctr -n k8s.io images rm 2>/dev/null || true
fi

# 9. 清理临时文件
rm -f kubeadm-config.yaml 2>/dev/null || true
rm -f tigera-operator.yaml 2>/dev/null || true
rm -f calico-custom-resources.yaml 2>/dev/null || true

# 10. 清理环境变量
sed -i '/export KUBECONFIG/d' /etc/profile 2>/dev/null || true
sed -i '/export PATH.*kube/d' /etc/profile 2>/dev/null || true

echo "✓ 旧版本Kubernetes环境清理完成"
