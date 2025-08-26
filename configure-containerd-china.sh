#!/bin/bash

# 配置containerd使用国内镜像源

echo "=========================================="
echo "配置containerd使用国内镜像源"
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

echo "1. 备份原始containerd配置..."

# 备份原始配置
if [ -f "/etc/containerd/config.toml" ]; then
    cp /etc/containerd/config.toml /etc/containerd/config.toml.backup
    echo "✓ 原始配置已备份到 /etc/containerd/config.toml.backup"
else
    echo "⚠️ 未找到原始配置文件"
fi

echo ""
echo "2. 配置containerd使用国内镜像源..."

# 创建优化的containerd配置
cat > /etc/containerd/config.toml << 'EOF'
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        # Docker Hub镜像
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = [
            "https://docker.mirrors.ustc.edu.cn",
            "https://hub-mirror.c.163.com",
            "https://mirror.baidubce.com",
            "https://registry.docker-cn.com"
          ]
        # Kubernetes镜像
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = [
            "https://registry.aliyuncs.com/google_containers",
            "https://registry.cn-hangzhou.aliyuncs.com/google_containers"
          ]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = [
            "https://registry.aliyuncs.com/google_containers",
            "https://registry.cn-hangzhou.aliyuncs.com/google_containers"
          ]
        # Quay镜像
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
          endpoint = [
            "https://quay.mirrors.ustc.edu.cn",
            "https://mirror.quay.io"
          ]
        # Google镜像
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
          endpoint = [
            "https://gcr.mirrors.ustc.edu.cn"
          ]
        # 阿里云镜像
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.aliyuncs.com"]
          endpoint = ["https://registry.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.cn-hangzhou.aliyuncs.com"]
          endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
EOF

echo "✓ containerd配置已更新"

echo ""
echo "3. 重启containerd服务..."

# 重启containerd
systemctl restart containerd

# 检查服务状态
if systemctl is-active --quiet containerd; then
    echo "✓ containerd服务已重启并正常运行"
else
    echo "⚠️ containerd服务启动失败，检查配置..."
    systemctl status containerd --no-pager -l
fi

echo ""
echo "4. 测试镜像拉取..."

# 测试拉取pause镜像
echo "测试拉取pause镜像..."
if ctr -n k8s.io images pull registry.aliyuncs.com/google_containers/pause:3.9; then
    echo "✓ pause镜像拉取成功"
else
    echo "⚠️ pause镜像拉取失败，尝试其他镜像源..."
    if ctr -n k8s.io images pull docker.io/library/pause:3.9; then
        echo "✓ 从Docker Hub拉取pause镜像成功"
    else
        echo "✗ 镜像拉取失败"
    fi
fi

echo ""
echo "=========================================="
echo "containerd国内镜像源配置完成！"
echo "=========================================="
echo ""
echo "配置的镜像源:"
echo "- Docker Hub: USTC、网易、百度云、Docker中国"
echo "- Kubernetes: 阿里云"
echo "- Quay: USTC、官方镜像"
echo "- Google: USTC"
echo "- 阿里云: 官方"
echo ""
echo "现在可以流畅地拉取各种镜像了！"
