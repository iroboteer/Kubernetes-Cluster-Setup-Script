#!/bin/bash

# 修复kubelet服务单元文件缺失问题

echo "=========================================="
echo "修复kubelet服务单元文件"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "检查kubelet服务状态..."

# 检查kubelet服务是否存在
if systemctl list-unit-files | grep -q kubelet; then
    echo "✓ kubelet服务单元文件已存在"
    systemctl status kubelet --no-pager -l
else
    echo "✗ kubelet服务单元文件不存在，正在创建..."
    
    # 创建kubelet服务单元文件
    cat > /etc/systemd/system/kubelet.service << 'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    echo "✓ kubelet服务单元文件已创建"
    
    # 重新加载systemd配置
    echo "重新加载systemd配置..."
    systemctl daemon-reload
    
    # 启用kubelet服务
    echo "启用kubelet服务..."
    systemctl enable kubelet
    
    echo "✓ kubelet服务已启用"
fi

echo ""
echo "检查kubelet二进制文件..."

# 检查kubelet二进制文件
if command -v kubelet &> /dev/null; then
    echo "✓ kubelet二进制文件找到: $(which kubelet)"
    echo "版本: $(kubelet --version)"
else
    echo "✗ kubelet二进制文件未找到"
    echo "请先安装Kubernetes组件"
    exit 1
fi

echo ""
echo "检查kubelet配置目录..."

# 创建kubelet配置目录
if [ ! -d "/var/lib/kubelet" ]; then
    echo "创建kubelet配置目录..."
    mkdir -p /var/lib/kubelet
    echo "✓ /var/lib/kubelet 目录已创建"
else
    echo "✓ /var/lib/kubelet 目录已存在"
fi

if [ ! -d "/etc/kubernetes" ]; then
    echo "创建kubernetes配置目录..."
    mkdir -p /etc/kubernetes
    echo "✓ /etc/kubernetes 目录已创建"
else
    echo "✓ /etc/kubernetes 目录已存在"
fi

echo ""
echo "=========================================="
echo "修复完成！"
echo "=========================================="
echo ""
echo "kubelet服务状态:"
systemctl status kubelet --no-pager -l
echo ""
echo "现在可以继续安装控制平面:"
echo "./02-install-control-plane.sh"
