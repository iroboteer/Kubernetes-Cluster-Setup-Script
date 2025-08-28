#!/bin/bash

# Kubernetes集群系统准备脚本
# 适用于CentOS Stream 10

set -e

echo "=========================================="
echo "开始准备系统环境..."
echo "=========================================="

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root用户身份运行"
   exit 1
fi

# 检查操作系统版本
if ! grep -q "CentOS Stream release 10" /etc/redhat-release; then
    echo "警告: 此脚本专为CentOS Stream 10设计"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. 关闭防火墙
echo "1. 关闭防火墙..."
if systemctl list-unit-files | grep -q firewalld; then
    systemctl stop firewalld 2>/dev/null || echo "firewalld服务未运行"
    systemctl disable firewalld 2>/dev/null || echo "firewalld服务未启用"
    echo "防火墙已关闭"
else
    echo "firewalld服务未安装"
fi

# 2. 禁用SELinux
echo "2. 禁用SELinux..."
# 检查SELinux状态并安全地禁用它
if command -v setenforce &> /dev/null; then
    setenforce 0 2>/dev/null || echo "SELinux已经是禁用状态或无法设置"
else
    echo "setenforce命令不可用，SELinux可能未安装"
fi

# 修改SELinux配置文件
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
    echo "SELinux配置已更新为permissive模式"
else
    echo "SELinux配置文件不存在"
fi

# 3. 关闭swap
echo "3. 关闭swap..."
if swapon --show | grep -q .; then
    swapoff -a
    echo "已关闭所有swap分区"
else
    echo "没有活动的swap分区"
fi

# 注释掉fstab中的swap条目
if [ -f /etc/fstab ]; then
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "已注释掉fstab中的swap条目"
else
    echo "fstab文件不存在"
fi

# 4. 配置内核参数
echo "4. 配置内核参数..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 5. 配置阿里云镜像源
echo "5. 配置阿里云Kubernetes镜像源..."
cat > /etc/yum.repos.d/kubernetes-aliyun.repo << EOF
[kubernetes-aliyun]
name=Kubernetes Aliyun
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
priority=1
EOF

# 清理dnf缓存
dnf clean all
dnf makecache

# 6. 配置containerd
echo "6. 配置containerd..."
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml << EOF
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
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://hub-mirror.c.163.com", "https://mirror.baidubce.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
EOF

# 7. 安装containerd
echo "7. 安装containerd..."
# 检查containerd是否已安装
if command -v containerd &> /dev/null; then
    echo "containerd已安装: $(containerd --version)"
else
    echo "安装containerd..."
    
    # 直接使用备用安装方法，避免Docker镜像源问题
    echo "使用直接下载方式安装containerd..."
    # 下载containerd二进制文件
    CONTAINERD_VERSION="1.7.0"
    echo "下载containerd v${CONTAINERD_VERSION}..."
    
    # 创建临时目录
    mkdir -p /tmp/containerd-install
    cd /tmp/containerd-install
    
    # 下载containerd
    curl -LO "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
    
    if [ -f "containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" ]; then
        echo "解压containerd..."
        tar xvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
        
        # 复制二进制文件并设置权限
        cp bin/* /usr/local/bin/
        chmod +x /usr/local/bin/containerd
        chmod +x /usr/local/bin/containerd-shim
        chmod +x /usr/local/bin/containerd-shim-runc-v1
        chmod +x /usr/local/bin/containerd-shim-runc-v2
        chmod +x /usr/local/bin/ctr
        chmod +x /usr/local/bin/runc
        
        # 创建必要的目录
        mkdir -p /etc/containerd
        mkdir -p /var/lib/containerd
        mkdir -p /run/containerd
        
        # 生成默认配置
        /usr/local/bin/containerd config default > /etc/containerd/config.toml
        
        # 创建systemd服务文件
        mkdir -p /usr/local/lib/systemd/system
        cat > /usr/local/lib/systemd/system/containerd.service << EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
        
        # 复制服务文件到系统目录
        cp /usr/local/lib/systemd/system/containerd.service /etc/systemd/system/
        
        echo "✓ containerd 手动安装成功"
    else
        echo "✗ containerd 下载失败"
        exit 1
    fi
    
    # 清理临时目录
    cd /
    rm -rf /tmp/containerd-install
fi

# 启动containerd
echo "启动containerd服务..."

# 创建必要的目录（无论containerd是否已安装）
echo "创建containerd必要目录..."
mkdir -p /etc/containerd
mkdir -p /var/lib/containerd
mkdir -p /run/containerd

# 如果配置文件不存在，生成默认配置
if [ ! -f "/etc/containerd/config.toml" ]; then
    echo "生成containerd默认配置..."
    containerd config default > /etc/containerd/config.toml
fi

# 确保配置目录权限正确
chmod 600 /etc/containerd/config.toml
chown root:root /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd

# 查找containerd二进制文件位置
CONTAINERD_PATH=$(command -v containerd)
if [ -z "$CONTAINERD_PATH" ]; then
    echo "✗ containerd二进制文件不存在，请检查安装"
    exit 1
fi

echo "找到containerd: $CONTAINERD_PATH"

# 检查二进制文件权限
if [ ! -x "$CONTAINERD_PATH" ]; then
    echo "设置containerd执行权限..."
    chmod +x "$CONTAINERD_PATH"
fi

# 启动服务
systemctl start containerd

# 验证containerd是否正常运行
if systemctl is-active --quiet containerd; then
    echo "✓ containerd服务已启动"
else
    echo "警告: containerd服务启动失败"
    systemctl status containerd --no-pager -l
    
    # 尝试直接启动
    echo "尝试直接启动containerd..."
    $CONTAINERD_PATH &
    sleep 3
    if pgrep containerd > /dev/null; then
        echo "✓ containerd 直接启动成功"
    else
        echo "✗ containerd 启动失败，请检查日志"
        journalctl -xeu containerd.service --no-pager -l
    fi
fi

# 8. 安装Kubernetes组件
echo "8. 安装Kubernetes组件..."
# 检查Kubernetes组件是否已安装
if command -v kubeadm &> /dev/null && command -v kubectl &> /dev/null && command -v kubelet &> /dev/null; then
    echo "Kubernetes组件已安装:"
    echo "  kubeadm: $(kubeadm version --short)"
    echo "  kubectl: $(kubectl version --client --short)"
    echo "  kubelet: $(kubelet --version)"
else
    echo "安装Kubernetes组件..."
    
    # 清理并重建缓存
    dnf clean all
    dnf makecache
    
    # 安装阿里云源上的1.28版本
    echo "安装阿里云源上的Kubernetes 1.28版本..."
    if dnf install -y kubelet-1.28.0 kubeadm-1.28.0 kubectl-1.28.0 --disableexcludes=kubernetes; then
        echo "✓ Kubernetes 1.28.0 从阿里云源安装成功"
        
        # 显示安装的版本
        echo "安装的版本信息:"
        kubeadm version --short
        kubectl version --client --short
        kubelet --version
    else
        echo "✗ 从阿里云源安装1.28.0失败，尝试安装最新可用版本..."
        
        # 如果1.28.0不可用，安装最新可用版本
        if dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes; then
            echo "✓ Kubernetes最新版本从阿里云源安装成功"
            
            # 显示安装的版本
            echo "安装的版本信息:"
            kubeadm version --short
            kubectl version --client --short
            kubelet --version
        else
            echo "✗ 阿里云源安装失败，使用备用方法下载1.28.0..."
            
            # 备用方法：使用CDN下载1.28.0
            echo "使用CDN下载Kubernetes 1.28.0..."
            
            # 创建临时目录
            mkdir -p /tmp/k8s-install
            cd /tmp/k8s-install
            
            K8S_VERSION="v1.28.0"
            echo "下载版本: $K8S_VERSION"
            
            # 尝试多个CDN源
            CDN_URLS=(
                "https://cdn.dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/"
                "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/"
            )
            
            for cdn_url in "${CDN_URLS[@]}"; do
                echo "尝试从 $cdn_url 下载..."
                
                if curl -fLO "${cdn_url}kubeadm" && curl -fLO "${cdn_url}kubectl" && curl -fLO "${cdn_url}kubelet"; then
                    echo "✓ 从 $cdn_url 下载成功"
                    
                    # 设置执行权限并安装
                    chmod +x kubeadm kubectl kubelet
                    mv kubeadm kubectl kubelet /usr/local/bin/
                    break
                else
                    echo "✗ 从 $cdn_url 下载失败，尝试下一个CDN..."
                fi
            done
            
            # 如果所有CDN都失败，使用官方源
            if [ ! -f "/usr/local/bin/kubeadm" ]; then
                echo "所有CDN都失败，使用官方源..."
                
                curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm"
                curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
                curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet"
                
                chmod +x kubeadm kubectl kubelet
                mv kubeadm kubectl kubelet /usr/local/bin/
            fi
            
            # 清理临时目录
            cd /
            rm -rf /tmp/k8s-install
        fi
    fi
fi

# 9. 启用kubelet服务
echo "9. 启用kubelet服务..."
systemctl enable kubelet
systemctl start kubelet

if systemctl is-active --quiet kubelet; then
    echo "✓ kubelet服务已启动"
else
    echo "✗ kubelet服务启动失败"
    systemctl status kubelet --no-pager -l
fi

echo "=========================================="
echo "系统环境准备完成！"
echo "=========================================="
echo "请确保所有节点都运行了此脚本"
echo "然后运行 02-install-control-plane.sh 安装控制平面"
