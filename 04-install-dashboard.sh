#!/bin/bash

# Kubernetes Dashboard安装脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始安装Kubernetes Dashboard..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查kubectl是否可用
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl未找到，请先安装控制平面"
    echo "运行命令: ./02-install-control-plane.sh"
    exit 1
fi

# 检查集群状态
if ! kubectl get nodes &> /dev/null; then
    echo "错误: 无法连接到Kubernetes集群，请确保控制平面已正确安装"
    exit 1
fi

# 1. 下载Dashboard清单文件
echo "1. 下载Kubernetes Dashboard清单文件..."
curl -O https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# 2. 修改Dashboard配置以支持NodePort访问
echo "2. 修改Dashboard配置..."
sed -i 's/type: ClusterIP/type: NodePort/' recommended.yaml

# 3. 安装Dashboard
echo "3. 安装Kubernetes Dashboard..."
kubectl apply -f recommended.yaml

# 4. 等待Dashboard就绪
echo "4. 等待Dashboard就绪..."
kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n kubernetes-dashboard

# 5. 创建管理员用户
echo "5. 创建管理员用户..."
cat > dashboard-admin-user.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f dashboard-admin-user.yaml

# 6. 获取访问令牌
echo "6. 生成访问令牌..."
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h > dashboard-token.txt

# 7. 获取Dashboard端口
echo "7. 获取Dashboard访问信息..."
DASHBOARD_PORT=$(kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.ports[0].nodePort}')
MASTER_IP=$(hostname -I | awk '{print $1}')

# 8. 创建访问脚本
echo "8. 创建访问脚本..."
cat > access-dashboard.sh << EOF
#!/bin/bash
echo "=========================================="
echo "Kubernetes Dashboard访问信息"
echo "=========================================="
echo "Dashboard URL: https://$MASTER_IP:$DASHBOARD_PORT"
echo ""
echo "访问令牌:"
cat dashboard-token.txt
echo ""
echo "使用说明:"
echo "1. 在浏览器中访问: https://$MASTER_IP:$DASHBOARD_PORT"
echo "2. 选择'Token'登录方式"
echo "3. 复制上面的令牌进行登录"
echo ""
echo "注意: 如果无法访问，请检查防火墙设置"
echo "=========================================="
EOF

chmod +x access-dashboard.sh

# 9. 验证安装
echo "9. 验证Dashboard安装..."
echo "检查Dashboard Pod状态:"
kubectl get pods -n kubernetes-dashboard

echo ""
echo "检查Dashboard Service:"
kubectl get svc -n kubernetes-dashboard

# 10. 显示访问信息
echo "=========================================="
echo "Kubernetes Dashboard安装完成！"
echo "=========================================="
echo ""
echo "Dashboard访问信息:"
echo "URL: https://$MASTER_IP:$DASHBOARD_PORT"
echo ""
echo "访问令牌已保存到: dashboard-token.txt"
echo ""
echo "运行以下命令查看完整访问信息:"
echo "./access-dashboard.sh"
echo ""
echo "或者手动获取令牌:"
echo "kubectl -n kubernetes-dashboard create token admin-user"
echo ""
echo "如果需要在其他机器访问，请确保防火墙允许端口 $DASHBOARD_PORT"
