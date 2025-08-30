#!/bin/bash
# setup-proxy.sh
# 一键配置 containerd、kubelet 和系统 shell 的代理环境

PROXY="http://192.168.0.131:7890"
NO_PROXY="127.0.0.1,localhost,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,*.svc,cluster.local"

echo ">>> 配置 containerd 代理 ..."
sudo mkdir -p /etc/systemd/system/containerd.service.d
cat <<EOF | sudo tee /etc/systemd/system/containerd.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="NO_PROXY=$NO_PROXY"
EOF

echo ">>> 配置 kubelet 代理 ..."
sudo mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="NO_PROXY=$NO_PROXY"
EOF

echo ">>> 配置系统 shell 全局代理 ..."
cat <<EOF | sudo tee /etc/profile.d/proxy.sh
export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export NO_PROXY=$NO_PROXY
EOF

echo ">>> 重新加载 systemd 配置并重启服务 ..."
sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl restart kubelet

echo ">>> 完成！请重新登录 shell 以加载 /etc/profile.d/proxy.sh"

echo ">>> 测试代理配置 ..."
echo "测试访问谷歌以及从官方拉取镜像"

# 测试网络连接
echo "1. 测试网络连接..."
if curl -s --connect-timeout 10 --max-time 30 https://www.google.com > /dev/null; then
    echo "✓ 网络连接正常，可以访问 Google"
else
    echo "✗ 网络连接失败，无法访问 Google"
    echo "请检查代理服务器是否正常运行"
fi

# 测试 Docker Hub 连接
echo "2. 测试 Docker Hub 连接..."
if curl -s --connect-timeout 10 --max-time 30 https://registry-1.docker.io/v2/ > /dev/null; then
    echo "✓ Docker Hub 连接正常"
else
    echo "✗ Docker Hub 连接失败"
fi

# 测试 containerd 拉取镜像
echo "3. 测试 containerd 拉取镜像..."
if sudo ctr images pull docker.io/library/hello-world:latest > /dev/null 2>&1; then
    echo "✓ containerd 可以成功拉取镜像"
    # 清理测试镜像
    sudo ctr images rm docker.io/library/hello-world:latest > /dev/null 2>&1
else
    echo "✗ containerd 拉取镜像失败"
    echo "请检查代理配置和网络连接"
fi

# 测试 Kubernetes 镜像仓库
echo "4. 测试 Kubernetes 镜像仓库..."
if curl -s --connect-timeout 10 --max-time 30 https://registry.k8s.io/v2/ > /dev/null; then
    echo "✓ Kubernetes 镜像仓库连接正常"
else
    echo "✗ Kubernetes 镜像仓库连接失败"
fi

echo ">>> 代理配置测试完成！"
echo "如果所有测试都通过，说明代理配置成功"
echo "如果有测试失败，请检查代理服务器配置和网络连接"
