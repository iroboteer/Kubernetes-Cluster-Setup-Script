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
    echo "1. 安装控制平面 (主节点)"
    echo "2. 安装Calico网络插件 (主节点)"
    echo "3. 工作节点加入集群 (工作节点)"
    echo "4. 打印工作节点加入集群指令 (主节点)"
    echo "5. 显示集群状态 (主节点)"
    echo "6. 退出"
    echo ""
}

# 自动系统准备（不显示菜单）
prepare_system_auto() {
    echo "自动准备系统环境..."
    chmod +x 01-prepare-system.sh
    ./01-prepare-system.sh
}

# 自动安装Kubernetes 1.28版本
install_k8s_1_28_auto() {
    echo "自动安装Kubernetes 1.28版本..."
    # 直接调用01-prepare-system.sh，它已经包含了1.28的安装逻辑
    chmod +x 01-prepare-system.sh
    ./01-prepare-system.sh
}

# 安装控制平面
install_control_plane() {
    echo "=========================================="
    echo "安装Kubernetes控制平面 (1.28)"
    echo "=========================================="
    
    # 自动完成所有准备工作
    echo "1. 自动准备系统环境..."
    prepare_system_auto
    
    echo "2. 安装Kubernetes 1.28组件..."
    install_k8s_1_28_auto
    
    echo "3. 安装控制平面..."
    chmod +x 02-install-control-plane.sh
    ./02-install-control-plane.sh
}

# 安装Calico
install_calico() {
    echo "=========================================="
    echo "安装Calico网络插件"
    echo "=========================================="
    
    # 检查kubectl是否可用
    if ! command -v kubectl &> /dev/null; then
        echo "检测到kubectl未安装，请先安装控制平面..."
        install_control_plane
    fi
    
    chmod +x 03-install-calico.sh
    ./03-install-calico.sh
}

# 工作节点加入
join_worker() {
    echo "=========================================="
    echo "工作节点加入集群"
    echo "=========================================="
    
    # 自动完成所有准备工作
    echo "1. 自动准备系统环境..."
    prepare_system_auto
    
    echo "2. 安装Kubernetes 1.28组件..."
    install_k8s_1_28_auto
    
    echo "3. 加入集群..."
    chmod +x 05-join-worker-node.sh
    ./05-join-worker-node.sh
}

# 打印工作节点加入集群指令
print_join_command() {
    echo "=========================================="
    echo "工作节点加入集群指令"
    echo "=========================================="
    
    if command -v kubeadm &> /dev/null; then
        echo "请保存以下命令，用于工作节点加入集群："
        echo ""
        kubeadm token create --print-join-command
        echo ""
        echo "或者运行以下命令获取完整的加入命令："
        echo "kubeadm init phase upload-certs --upload-certs"
        echo "kubeadm token create --print-join-command"
    else
        echo "kubeadm未找到，请先安装控制平面"
    fi
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

# 主循环
while true; do
    show_menu
    read -p "请输入选项 (1-6): " choice
    
    case $choice in
        1)
            install_control_plane
            ;;
        2)
            install_calico
            ;;
        3)
            join_worker
            ;;
        4)
            print_join_command
            ;;
        5)
            show_cluster_status
            ;;
        6)
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
