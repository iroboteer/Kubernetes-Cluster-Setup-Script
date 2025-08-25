#!/bin/bash

# 快速修复脚本 - 解决SELinux和其他常见问题

echo "=========================================="
echo "快速修复脚本"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "正在修复SELinux问题..."

# 1. 安全地处理SELinux
echo "1. 处理SELinux..."
if command -v setenforce &> /dev/null; then
    echo "尝试禁用SELinux..."
    setenforce 0 2>/dev/null && echo "✓ SELinux已禁用" || echo "⚠ SELinux已经是禁用状态"
else
    echo "✓ setenforce命令不可用，SELinux可能未安装"
fi

# 修改SELinux配置文件
if [ -f /etc/selinux/config ]; then
    echo "更新SELinux配置文件..."
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
    echo "✓ SELinux配置已更新"
else
    echo "⚠ SELinux配置文件不存在"
fi

# 2. 处理防火墙
echo ""
echo "2. 处理防火墙..."
if systemctl list-unit-files | grep -q firewalld; then
    systemctl stop firewalld 2>/dev/null && echo "✓ firewalld已停止" || echo "⚠ firewalld未运行"
    systemctl disable firewalld 2>/dev/null && echo "✓ firewalld已禁用" || echo "⚠ firewalld未启用"
else
    echo "✓ firewalld未安装"
fi

# 3. 处理swap
echo ""
echo "3. 处理swap..."
if swapon --show | grep -q .; then
    swapoff -a && echo "✓ 已关闭所有swap分区" || echo "⚠ 关闭swap失败"
else
    echo "✓ 没有活动的swap分区"
fi

if [ -f /etc/fstab ]; then
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "✓ 已注释掉fstab中的swap条目"
else
    echo "⚠ fstab文件不存在"
fi

# 4. 检查系统状态
echo ""
echo "4. 检查系统状态..."
echo "SELinux状态:"
if command -v getenforce &> /dev/null; then
    getenforce
else
    echo "getenforce命令不可用"
fi

echo ""
echo "防火墙状态:"
systemctl status firewalld --no-pager -l 2>/dev/null || echo "firewalld未安装或未运行"

echo ""
echo "swap状态:"
swapon --show || echo "没有活动的swap分区"

echo ""
echo "=========================================="
echo "修复完成！"
echo "=========================================="
echo ""
echo "现在可以继续运行安装脚本:"
echo "./00-master-install.sh"
echo ""
echo "或者直接运行系统准备:"
echo "./01-prepare-system.sh"
