#!/bin/bash

# 给所有脚本添加执行权限
echo "=========================================="
echo "Kubernetes集群构建脚本安装"
echo "=========================================="

# 给所有.sh文件添加执行权限
chmod +x *.sh

echo "已给以下脚本添加执行权限:"
ls -la *.sh

echo ""
echo "安装完成！"
echo ""
echo "使用方法:"
echo "1. 在主节点上运行: ./00-master-install.sh"
echo "2. 选择选项 6 进行一键安装"
echo "3. 在工作节点上运行: ./00-master-install.sh"
echo "4. 选择选项 5 加入集群"
echo ""
echo "详细说明请查看 README.md"
