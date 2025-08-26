#!/bin/bash

# Kubernetes集群系统准备脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始准备系统环境..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查操作系统版本
if ! grep -q "CentOS Stream release 10" /etc/redhat-release; then
    echo "警告: 此脚本专为CentOS Stream 10设计"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. 关闭防火墙
echo "1. 关闭防火墙..."
if systemctl list-unit-files | grep -q firewalld; then
    systemctl stop firewalld 2>/dev/null || echo "firewalld服务未运行"
    systemctl disable firewalld 2>/dev/null || echo "firewalld服务未启用"
    echo "防火墙已关闭"
else
    echo "firewalld服务未安装"
fi

# 2. 禁用SELinux
echo "2. 禁用SELinux..."
# 检查SELinux状态并安全地禁用它
if command -v setenforce &> /dev/null; then
    setenforce 0 2>/dev/null || echo "SELinux已经是禁用状态或无法设置"
else
    echo "setenforce命令不可用，SELinux可能未安装"
fi

# 修改SELinux配置文件
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
    echo "SELinux配置已更新为permissive模式"
else
    echo "SELinux配置文件不存在"
fi

# 3. 关闭swap
echo "3. 关闭swap..."
if swapon --show | grep -q .; then
    swapoff -a
    echo "已关闭所有swap分区"
else
    echo "没有活动的swap分区"
fi

# 注释掉fstab中的swap条目
if [ -f /etc/fstab ]; then
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "已注释掉fstab中的swap条目"
else
    echo "fstab文件不存在"
fi

# 4. 配置内核参数
echo "4. 配置内核参数..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 5. 配置阿里云镜像源
echo "5. 配置阿里云镜像源..."
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

# 清理dnf缓存
dnf clean all
dnf makecache

# 6. 配置containerd
echo "6. 配置containerd..."
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml << EOF
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://docker.mirrors.ustc.edu.cn", "https://hub-mirror.c.163.com", "https://mirror.baidubce.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
EOF

# 7. 安装containerd
echo "7. 安装containerd..."
# 检查containerd是否已安装
if command -v containerd &> /dev/null; then
    echo "containerd已安装: $(containerd --version)"
else
    echo "安装containerd..."
    dnf install -y containerd.io
    
    # 如果yum安装失败，尝试备用方法
    if ! command -v containerd &> /dev/null; then
        echo "yum安装失败，尝试备用安装方法..."
        # 下载containerd二进制文件
        CONTAINERD_VERSION="1.7.0"
        curl -LO "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
        tar xvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
        cp bin/* /usr/local/bin/
        rm -rf bin containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
    fi
fi

# 启动containerd
echo "启动containerd服务..."
systemctl daemon-reload
systemctl enable containerd
systemctl start containerd

# 验证containerd是否正常运行
if systemctl is-active --quiet containerd; then
    echo "containerd服务已启动"
else
    echo "警告: containerd服务启动失败"
    systemctl status containerd --no-pager -l
fi

# 重启containerd以应用新配置
systemctl restart containerd

# 8. 安装kubeadm, kubelet, kubectl
echo "8. 安装Kubernetes组件..."
# 检查Kubernetes组件是否已安装
if command -v kubeadm &> /dev/null && command -v kubectl &> /dev/null && command -v kubelet &> /dev/null; then
    echo "Kubernetes组件已安装:"
    echo "  kubeadm: $(kubeadm version --short)"
    echo "  kubectl: $(kubectl version --client --short)"
    echo "  kubelet: $(kubelet --version)"
else
    echo "安装Kubernetes组件..."
    
    # 清理并重建缓存
    dnf clean all
    dnf makecache
    
    # 尝试安装Kubernetes组件
    echo "尝试dnf安装Kubernetes组件..."
    
    # 检查是否有exclude配置
    if grep -r "exclude.*kube" /etc/yum.repos.d/ /etc/yum.conf 2>/dev/null; then
        echo "发现exclude配置，正在清理..."
        # 清理所有exclude配置
        sed -i '/exclude.*kube/d' /etc/yum.repos.d/*.repo /etc/yum.conf 2>/dev/null || true
        dnf clean all
        dnf makecache
    fi
    
    # 尝试安装Kubernetes 1.33.4
    echo "尝试安装Kubernetes 1.33.4..."
    if dnf install -y kubelet-1.33.4 kubeadm-1.33.4 kubectl-1.33.4; then
        echo "✓ Kubernetes 1.33.4安装成功"
    else
        echo "通过yum安装失败，尝试备用方法..."
        
        # 备用安装方法：直接下载二进制文件
        echo "使用备用安装方法..."
        
        # 创建临时目录
        mkdir -p /tmp/k8s-install
        cd /tmp/k8s-install
        
        K8S_VERSION="v1.33.4"
        
        # 下载kubeadm
        echo "下载kubeadm..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm"
        chmod +x kubeadm
        mv kubeadm /usr/local/bin/
        
        # 下载kubectl
        echo "下载kubectl..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl /usr/local/bin/
        
        # 下载kubelet
        echo "下载kubelet..."
        curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet"
        chmod +x kubelet
        mv kubelet /usr/local/bin/
        
        # 清理临时目录
        cd /
        rm -rf /tmp/k8s-install
        
        echo "✓ Kubernetes 1.33.4已通过备用方法安装"
    fi
fi

# 检查并修复PATH问题
echo "检查Kubernetes组件安装位置..."
KUBEADM_PATH=$(which kubeadm 2>/dev/null || find /usr/bin /usr/local/bin /opt -name kubeadm 2>/dev/null | head -1)
KUBECTL_PATH=$(which kubectl 2>/dev/null || find /usr/bin /usr/local/bin /opt -name kubectl 2>/dev/null | head -1)
KUBELET_PATH=$(which kubelet 2>/dev/null || find /usr/bin /usr/local/bin /opt -name kubelet 2>/dev/null | head -1)

if [ -n "$KUBEADM_PATH" ]; then
    echo "✓ kubeadm找到: $KUBEADM_PATH"
else
    echo "✗ kubeadm未找到，尝试重新安装..."
    # 强制重新安装
    echo "强制重新安装Kubernetes组件..."
    dnf remove -y kubelet kubeadm kubectl 2>/dev/null || true
    
    # 确保没有exclude配置
    sed -i '/exclude.*kube/d' /etc/yum.repos.d/*.repo /etc/yum.conf 2>/dev/null || true
    dnf clean all
    dnf makecache
    
    dnf install -y kubelet kubeadm kubectl
fi

if [ -n "$KUBECTL_PATH" ]; then
    echo "✓ kubectl找到: $KUBECTL_PATH"
else
    echo "✗ kubectl未找到"
fi

if [ -n "$KUBELET_PATH" ]; then
    echo "✓ kubelet找到: $KUBELET_PATH"
else
    echo "✗ kubelet未找到"
fi

# 确保PATH包含Kubernetes组件路径
if ! echo "$PATH" | grep -q "/usr/bin"; then
    echo "添加/usr/bin到PATH..."
    export PATH="/usr/bin:$PATH"
    echo 'export PATH="/usr/bin:$PATH"' >> /etc/profile
fi

# 启用kubelet
echo "启用kubelet服务..."
systemctl enable kubelet

echo "Kubernetes组件安装完成"

echo "=========================================="
echo "系统环境准备完成！"
echo "=========================================="
echo "请确保所有节点都运行了此脚本"
echo "然后运行 02-install-control-plane.sh 安装控制平面"
