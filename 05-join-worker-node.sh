#!/bin/bash

# Kubernetes工作节点加入集群脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始加入Kubernetes集群..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查是否已经运行了系统准备脚本
if ! command -v kubeadm &> /dev/null; then
    echo "错误: kubeadm未找到"
    echo "正在自动运行系统环境准备脚本..."
    
    # 检查01-prepare-system.sh是否存在
    if [ -f "01-prepare-system.sh" ]; then
        chmod +x 01-prepare-system.sh
        ./01-prepare-system.sh
    else
        echo "错误: 01-prepare-system.sh 脚本不存在"
        exit 1
    fi
    
    # 再次检查kubeadm
    if ! command -v kubeadm &> /dev/null; then
        echo "错误: 系统环境准备后仍无法找到kubeadm"
        exit 1
    fi
fi

# 检查containerd是否已安装并运行
if ! command -v containerd &> /dev/null; then
    echo "错误: containerd未找到，请先运行 01-prepare-system.sh"
    exit 1
fi

if ! systemctl is-active --quiet containerd; then
    echo "错误: containerd服务未运行，请先启动containerd"
    echo "运行命令: systemctl start containerd"
    exit 1
fi

# 检查是否已经加入集群
if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "警告: 此节点似乎已经加入了Kubernetes集群"
    read -p "是否要重新加入? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    echo "重置节点..."
    kubeadm reset -f
fi

# 获取控制平面信息
echo "请输入控制平面信息:"
read -p "控制平面IP地址: " MASTER_IP
read -p "加入令牌: " JOIN_TOKEN
read -p "证书哈希 (可选，按回车跳过): " CERT_HASH

if [ -z "$MASTER_IP" ] || [ -z "$JOIN_TOKEN" ]; then
    echo "错误: 控制平面IP和加入令牌是必需的"
    exit 1
fi

echo "使用以下配置:"
echo "控制平面IP: $MASTER_IP"
echo "加入令牌: $JOIN_TOKEN"
if [ ! -z "$CERT_HASH" ]; then
    echo "证书哈希: $CERT_HASH"
fi

read -p "确认继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 1. 加入集群
echo "1. 加入Kubernetes集群..."
if [ ! -z "$CERT_HASH" ]; then
    kubeadm join $MASTER_IP:6443 --token $JOIN_TOKEN --discovery-token-ca-cert-hash sha256:$CERT_HASH
else
    kubeadm join $MASTER_IP:6443 --token $JOIN_TOKEN --discovery-token-unsafe-skip-ca-verification
fi

# 2. 等待节点就绪
echo "2. 等待节点就绪..."
echo "这可能需要几分钟时间..."

# 检查kubelet状态
systemctl is-active --quiet kubelet || {
    echo "启动kubelet服务..."
    systemctl start kubelet
    systemctl enable kubelet
}

# 3. 验证节点状态
echo "3. 验证节点状态..."
echo "检查kubelet状态:"
systemctl status kubelet --no-pager -l

echo ""
echo "检查节点是否已加入集群:"
echo "请在控制平面节点上运行: kubectl get nodes"

# 4. 显示节点信息
echo "4. 显示节点信息..."
NODE_NAME=$(hostname)
echo "节点名称: $NODE_NAME"
echo "节点IP: $(hostname -I | awk '{print $1}')"

# 5. 创建验证脚本
echo "5. 创建验证脚本..."
cat > verify-node.sh << EOF
#!/bin/bash
echo "=========================================="
echo "节点验证信息"
echo "=========================================="
echo "节点名称: $NODE_NAME"
echo "节点IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "kubelet状态:"
systemctl status kubelet --no-pager -l
echo ""
echo "Docker状态:"
systemctl status docker --no-pager -l
echo ""
echo "网络接口:"
ip addr show
echo ""
echo "请在控制平面节点上运行以下命令验证:"
echo "kubectl get nodes"
echo "kubectl describe node $NODE_NAME"
echo "=========================================="
EOF

chmod +x verify-node.sh

echo "=========================================="
echo "工作节点加入完成！"
echo "=========================================="
echo ""
echo "节点信息:"
echo "- 节点名称: $NODE_NAME"
echo "- 节点IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "请在控制平面节点上运行: kubectl get nodes 验证节点状态"
