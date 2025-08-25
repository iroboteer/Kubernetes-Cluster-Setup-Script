#!/bin/bash

# Calico网络插件安装脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始安装Calico网络插件..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查kubectl是否可用
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl未找到，请先安装控制平面"
    exit 1
fi

# 检查集群状态
if ! kubectl get nodes &> /dev/null; then
    echo "错误: 无法连接到Kubernetes集群，请确保控制平面已正确安装"
    exit 1
fi

# 获取Pod网络CIDR
POD_CIDR=$(kubectl cluster-info dump | grep -m 1 cluster-cidr | awk -F'"' '{print $4}')
if [ -z "$POD_CIDR" ]; then
    POD_CIDR="10.244.0.0/16"
    echo "警告: 无法自动检测Pod网络CIDR，使用默认值: $POD_CIDR"
fi

echo "检测到Pod网络CIDR: $POD_CIDR"

# 1. 下载Calico清单文件
echo "1. 下载Calico清单文件..."
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# 2. 安装Calico Operator
echo "2. 安装Calico Operator..."
kubectl create -f tigera-operator.yaml

# 3. 等待Operator就绪
echo "3. 等待Calico Operator就绪..."
kubectl wait --for=condition=available --timeout=300s deployment/tigera-operator -n tigera-operator

# 4. 创建Calico自定义资源
echo "4. 创建Calico自定义资源..."
cat > calico-custom-resources.yaml << EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  cni:
    type: Calico
  ipPools:
  - blockSize: 26
    cidr: $POD_CIDR
    encapsulation: VXLANCrossSubnet
    natOutgoing: Enabled
    nodeSelector: all()
  typhaMetricsPort: 9093
  nodeMetricsPort: 9091
  flexVolumePath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
  nodeUpdateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  componentResources:
  - componentName: Node
    resourceRequirements:
      requests:
        memory: 250Mi
        cpu: 250m
      limits:
        memory: 500Mi
        cpu: 500m
  - componentName: Typha
    resourceRequirements:
      requests:
        memory: 64Mi
        cpu: 100m
      limits:
        memory: 500Mi
        cpu: 500m
EOF

kubectl create -f calico-custom-resources.yaml

# 5. 等待Calico安装完成
echo "5. 等待Calico安装完成..."
echo "这可能需要几分钟时间..."

# 等待Calico DaemonSet就绪
kubectl wait --for=condition=available --timeout=600s daemonset/calico-node -n calico-system

# 等待Calico Typha就绪
kubectl wait --for=condition=available --timeout=300s deployment/calico-typha -n calico-system

# 6. 验证安装
echo "6. 验证Calico安装..."
echo "检查Calico Pod状态:"
kubectl get pods -n calico-system

echo ""
echo "检查节点状态:"
kubectl get nodes

echo ""
echo "检查网络策略:"
kubectl get networkpolicies --all-namespaces

# 7. 创建测试Pod验证网络连通性
echo "7. 创建测试Pod验证网络连通性..."
cat > test-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  labels:
    app: test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

kubectl apply -f test-pod.yaml

# 等待测试Pod运行
kubectl wait --for=condition=ready --timeout=60s pod/test-pod

echo ""
echo "测试Pod状态:"
kubectl get pod test-pod

# 清理测试Pod
kubectl delete -f test-pod.yaml

echo "=========================================="
echo "Calico网络插件安装完成！"
echo "=========================================="
echo ""
echo "网络插件状态:"
kubectl get pods -n calico-system
echo ""
echo "接下来可以运行:"
echo "- 04-install-dashboard.sh (安装Kubernetes Dashboard)"
echo "- 05-join-worker-node.sh (在工作节点上运行)"
