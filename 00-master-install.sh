#!/bin/bash

# Kubernetes集群一键安装主控制脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "Kubernetes集群一键安装脚本"
echo "适用于CentOS Stream 10"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 显示菜单
show_menu() {
    echo ""
    echo "请选择要执行的操作:"
    echo "1. 系统环境准备 (所有节点都需要运行)"
    echo "2. 安装控制平面 (仅在主节点运行)"
    echo "3. 安装Calico网络插件 (仅在主节点运行)"
    echo "4. 安装Kubernetes Dashboard (仅在主节点运行)"
    echo "5. 工作节点加入集群 (在工作节点运行)"
    echo "6. 一键安装完整集群 (主节点)"
    echo "7. 清除Kubernetes集群"
    echo "8. 查看集群状态"
    echo "9. 诊断和修复安装问题"
    echo "10. 退出"
    echo ""
}

# 执行系统准备
prepare_system() {
    echo "执行系统环境准备..."
    chmod +x 01-prepare-system.sh
    ./01-prepare-system.sh
}

# 安装控制平面
install_control_plane() {
    echo "安装控制平面..."
    chmod +x 02-install-control-plane.sh
    ./02-install-control-plane.sh
}

# 安装Calico
install_calico() {
    echo "安装Calico网络插件..."
    chmod +x 03-install-calico.sh
    ./03-install-calico.sh
}

# 安装Dashboard
install_dashboard() {
    echo "安装Kubernetes Dashboard..."
    chmod +x 04-install-dashboard.sh
    ./04-install-dashboard.sh
}

# 工作节点加入
join_worker() {
    echo "工作节点加入集群..."
    chmod +x 05-join-worker-node.sh
    ./05-join-worker-node.sh
}

# 一键安装完整集群
install_full_cluster() {
    echo "开始一键安装完整Kubernetes集群..."
    echo ""
    echo "此操作将按顺序执行:"
    echo "1. 系统环境准备"
    echo "2. 安装控制平面"
    echo "3. 安装Calico网络插件"
    echo "4. 安装Kubernetes Dashboard"
    echo ""
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        return
    fi
    
    echo "=========================================="
    echo "开始一键安装..."
    echo "=========================================="
    
    # 1. 系统准备
    echo "步骤 1/4: 系统环境准备"
    prepare_system
    
    # 2. 安装控制平面
    echo "步骤 2/4: 安装控制平面"
    install_control_plane
    
    # 3. 安装Calico
    echo "步骤 3/4: 安装Calico网络插件"
    install_calico
    
    # 4. 安装Dashboard
    echo "步骤 4/4: 安装Kubernetes Dashboard"
    install_dashboard
    
    echo "=========================================="
    echo "Kubernetes集群安装完成！"
    echo "=========================================="
    echo ""
    echo "集群信息:"
    kubectl get nodes
    echo ""
    echo "Dashboard访问信息:"
    if [ -f "access-dashboard.sh" ]; then
        ./access-dashboard.sh
    fi
    echo ""
    echo "接下来可以在工作节点上运行:"
    echo "./00-master-install.sh 并选择选项 5"
}

# 清除集群
cleanup_cluster() {
    echo "清除Kubernetes集群..."
    chmod +x 06-cleanup-kubernetes.sh
    ./06-cleanup-kubernetes.sh
}

# 查看集群状态
show_cluster_status() {
    echo "=========================================="
    echo "Kubernetes集群状态"
    echo "=========================================="
    
    if command -v kubectl &> /dev/null; then
        echo "节点状态:"
        kubectl get nodes
        echo ""
        echo "Pod状态:"
        kubectl get pods --all-namespaces
        echo ""
        echo "服务状态:"
        kubectl get services --all-namespaces
        echo ""
        echo "网络策略:"
        kubectl get networkpolicies --all-namespaces
    else
        echo "kubectl未找到，请先安装Kubernetes"
    fi
}

# 诊断和修复
diagnose_and_fix() {
    echo "诊断和修复安装问题..."
    chmod +x fix-installation.sh
    ./fix-installation.sh
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 (1-10): " choice
    
            case $choice in
        1)
            prepare_system
            ;;
        2)
            install_control_plane
            ;;
        3)
            install_calico
            ;;
        4)
            install_dashboard
            ;;
        5)
            join_worker
            ;;
        6)
            install_full_cluster
            ;;
        7)
            cleanup_cluster
            ;;
        8)
            show_cluster_status
            ;;
        9)
            diagnose_and_fix
            ;;
        10)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效选项，请重新选择"
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
done
