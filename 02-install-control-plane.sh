#!/bin/bash

# Kubernetes控制平面安装脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始安装Kubernetes控制平面..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查kubeadm是否已安装
check_kubeadm() {
    # 首先尝试直接查找
    if command -v kubeadm &> /dev/null; then
        return 0
    fi
    
    # 如果找不到，尝试在常见路径中查找
    KUBEADM_PATH=$(find /usr/bin /usr/local/bin /opt -name kubeadm 2>/dev/null | head -1)
    if [ -n "$KUBEADM_PATH" ]; then
        echo "找到kubeadm: $KUBEADM_PATH"
        export PATH="$(dirname $KUBEADM_PATH):$PATH"
        return 0
    fi
    
    return 1
}

if ! check_kubeadm; then
    echo "错误: kubeadm未找到"
    echo "正在自动运行系统环境准备脚本..."
    
    # 检查01-prepare-system.sh是否存在
    if [ -f "01-prepare-system.sh" ]; then
        chmod +x 01-prepare-system.sh
        ./01-prepare-system.sh
        
        # 重新加载环境变量
        source /etc/profile
        
        # 再次检查kubeadm
        if ! check_kubeadm; then
            echo "错误: 系统环境准备后仍无法找到kubeadm"
            echo "尝试手动查找kubeadm..."
            find / -name kubeadm 2>/dev/null | head -5
            echo "请检查Kubernetes组件是否正确安装"
            exit 1
        fi
    else
        echo "错误: 01-prepare-system.sh 脚本不存在"
        exit 1
    fi
fi

# 检查containerd是否已安装
if ! command -v containerd >/dev/null 2>&1; then
    echo "错误: containerd未安装，请先安装containerd"
    echo "运行命令: ./01-prepare-system.sh"
    exit 1
fi

# 检查containerd版本
if ! containerd -v >/dev/null 2>&1; then
    echo "错误: 无法获取containerd版本，请检查containerd安装状态"
    exit 1
fi
echo "检测到containerd版本: $(containerd -v)"

# 获取本机IP地址
MASTER_IP=$(hostname -I | awk '{print $1}')
echo "检测到本机IP: $MASTER_IP"

# 询问用户确认IP地址
read -p "请确认控制平面IP地址 [$MASTER_IP]: " CONFIRMED_IP
MASTER_IP=${CONFIRMED_IP:-$MASTER_IP}

# 询问Pod网络CIDR
read -p "请输入Pod网络CIDR [10.244.0.0/16]: " POD_CIDR
POD_CIDR=${POD_CIDR:-10.244.0.0/16}

# 询问Service网络CIDR
read -p "请输入Service网络CIDR [10.96.0.0/12]: " SERVICE_CIDR
SERVICE_CIDR=${SERVICE_CIDR:-10.96.0.0/12}

echo "使用以下配置:"
echo "控制平面IP: $MASTER_IP"
echo "Pod网络CIDR: $POD_CIDR"
echo "Service网络CIDR: $SERVICE_CIDR"

read -p "确认继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 创建kubeadm配置文件
create_kubeadm_config() {
    local CONTROL_PLANE_IP=$1
    local POD_CIDR=$2
    local SERVICE_CIDR=$3
    local K8S_VERSION=1.33.4
    
    echo "使用Kubernetes版本: $K8S_VERSION"
    
    cat > kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $K8S_VERSION
controlPlaneEndpoint: "$CONTROL_PLANE_IP:6443"
networking:
  podSubnet: "$POD_CIDR"
  serviceSubnet: "$SERVICE_CIDR"
apiServer:
  certSANs:
  - "$CONTROL_PLANE_IP"
  - "localhost"
  - "127.0.0.1"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/containerd/containerd.sock"
EOF
}

# 1. 创建kubeadm配置文件
echo "1. 创建kubeadm配置文件..."
create_kubeadm_config "$MASTER_IP" "$POD_CIDR" "$SERVICE_CIDR"

# 2. 初始化控制平面
echo "2. 初始化Kubernetes控制平面..."
kubeadm init --config=kubeadm-config.yaml --upload-certs

# 3. 配置kubectl
echo "3. 配置kubectl..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 4. 配置环境变量
echo "4. 配置环境变量..."
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
source /etc/profile

# 5. 移除污点（允许在控制平面节点上调度Pod）
echo "5. 移除控制平面节点污点..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

# 6. 显示加入命令
echo "=========================================="
echo "控制平面安装完成！"
echo "=========================================="
echo ""
echo "请保存以下命令，用于工作节点加入集群："
echo ""
kubeadm token create --print-join-command
echo ""
echo "或者运行以下命令获取完整的加入命令："
echo "kubeadm init phase upload-certs --upload-certs"
echo "kubeadm token create --print-join-command"
echo ""
echo "接下来可以运行以下脚本："
echo "- 03-install-calico.sh (安装Calico网络插件)"
echo "- 04-install-dashboard.sh (安装Kubernetes Dashboard)"
echo "- 05-join-worker-node.sh (在工作节点上运行)"
