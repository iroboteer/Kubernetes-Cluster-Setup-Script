# Kubernetes集群构建脚本

这是一套完整的Kubernetes集群构建脚本，专为CentOS Stream 10系统设计。脚本包含了从系统准备到完整集群部署的所有步骤，并配置了阿里云镜像源以加速下载。

## 功能特性

- ✅ 系统环境自动准备
- ✅ 控制平面安装和初始化
- ✅ Calico网络插件安装
- ✅ 工作节点自动加入集群
- ✅ 阿里云镜像源配置
- ✅ 完整的错误检查和验证

## 系统要求

- **操作系统**: CentOS Stream 10
- **内存**: 至少2GB RAM
- **CPU**: 至少2个CPU核心
- **磁盘**: 至少20GB可用空间
- **网络**: 所有节点之间网络连通
- **权限**: root用户权限

## 脚本说明

### 核心脚本

| 脚本名称 | 用途 | 运行位置 |
|---------|------|----------|
| `00-master-install.sh` | 主控制脚本，提供菜单式操作 | 所有节点 |
| `01-prepare-system.sh` | 系统环境准备 | 所有节点 |
| `02-install-control-plane.sh` | 安装控制平面 | 主节点 |
| `03-install-calico.sh` | 安装Calico网络插件 | 主节点 |
| `05-join-worker-node.sh` | 工作节点加入集群 | 工作节点 |

## 快速开始

### 1. 下载脚本

```bash
# 确保所有脚本有执行权限
chmod +x *.sh
```

### 2. 主节点安装

在主节点上运行主控制脚本：

```bash
./00-master-install.sh
```

按步骤选择：

1. 选择 `1` - 安装控制平面
2. 选择 `2` - 安装Calico网络插件
3. 选择 `4` - 打印工作节点加入集群指令
4. 选择 `5` - 显示集群状态

### 3. 工作节点加入

在工作节点上运行：

```bash
./00-master-install.sh
```

选择选项 `3` - 工作节点加入集群，然后输入主节点提供的信息。

## 详细安装步骤

### 步骤1: 安装控制平面

在主节点上运行：

```bash
./00-master-install.sh
```

选择选项 `1` - 安装控制平面。此操作会自动：
- 准备系统环境
- 安装Kubernetes 1.28组件
- 初始化控制平面

### 步骤2: 安装Calico网络插件

在主节点上运行：

```bash
./00-master-install.sh
```

选择选项 `2` - 安装Calico网络插件。

### 步骤3: 工作节点加入集群

在工作节点上运行：

```bash
./00-master-install.sh
```

选择选项 `3` - 工作节点加入集群。

### 步骤4: 验证集群状态

在主节点上运行：

```bash
./00-master-install.sh
```

选择选项 `5` - 显示集群状态。

## 配置说明

### 镜像源配置

脚本使用阿里云镜像源加速下载：
- Kubernetes组件：`https://mirrors.aliyun.com/kubernetes/`
- Docker镜像：`https://registry.aliyuncs.com/google_containers`

### 网络配置

- Pod网络CIDR：`10.244.0.0/16`
- Service网络CIDR：`10.96.0.0/12`
- 网络插件：Calico

## 故障排除

### 常见问题

1. **kubeadm命令找不到**
   - 确保已运行系统准备脚本
   - 检查PATH环境变量

2. **控制平面启动失败**
   - 检查内存是否足够（至少2GB）
   - 检查网络连接
   - 检查防火墙设置

3. **工作节点无法加入集群**
   - 检查网络连通性
   - 验证加入令牌是否正确
   - 检查kubelet服务状态

### 日志查看

```bash
# 查看kubelet日志
journalctl -u kubelet -f

# 查看containerd日志
journalctl -u containerd -f

# 查看集群状态
kubectl get nodes
kubectl get pods --all-namespaces
```

## 版本信息

- Kubernetes版本：1.28.0
- Calico版本：3.26.1
- 支持系统：CentOS Stream 10

## 许可证

此项目采用MIT许可证。
