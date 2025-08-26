#!/bin/bash

# 清理所有USTC相关的镜像源配置

echo "=========================================="
echo "清理USTC镜像源配置"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "1. 清理yum/dnf仓库配置..."

# 删除USTC相关的repo文件
rm -f /etc/yum.repos.d/kubernetes-ustc.repo
rm -f /etc/yum.repos.d/*ustc*.repo
rm -f /etc/yum.repos.d/*USTC*.repo

echo "✓ USTC repo文件已删除"

echo ""
echo "2. 清理dnf缓存..."

# 清理dnf缓存
dnf clean all
dnf makecache

echo "✓ dnf缓存已清理并重建"

echo ""
echo "3. 检查剩余的repo配置..."

# 列出当前的repo配置
echo "当前配置的仓库:"
dnf repolist

echo ""
echo "4. 验证清理结果..."

# 检查是否还有USTC相关的配置
if dnf repolist | grep -i ustc; then
    echo "⚠️ 发现USTC仓库，请手动检查"
else
    echo "✓ 未发现USTC仓库"
fi

echo ""
echo "=========================================="
echo "USTC镜像源清理完成！"
echo "=========================================="
echo ""
echo "现在可以重新运行安装脚本，不会再出现USTC相关的错误。"
