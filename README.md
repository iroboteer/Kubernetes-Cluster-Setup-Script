# Kubernetes集群构建脚本

这是一套完整的Kubernetes集群构建脚本，专为CentOS Stream 10系统设计。脚本包含了从系统准备到完整集群部署的所有步骤，并配置了阿里云镜像源以加速下载。

## 功能特性

- ✅ 系统环境自动准备
- ✅ 控制平面安装和初始化
- ✅ Calico网络插件安装
- ✅ Kubernetes Dashboard管理界面
- ✅ 工作节点自动加入集群
- ✅ 一键清除Kubernetes集群
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

### 主要脚本

| 脚本名称 | 用途 | 运行位置 |
|---------|------|----------|
| `00-master-install.sh` | 主控制脚本，提供菜单式操作 | 所有节点 |
| `01-prepare-system.sh` | 系统环境准备 | 所有节点 |
| `02-install-control-plane.sh` | 安装控制平面 | 主节点 |
| `03-install-calico.sh` | 安装Calico网络插件 | 主节点 |
| `04-install-dashboard.sh` | 安装Kubernetes Dashboard | 主节点 |
| `05-join-worker-node.sh` | 工作节点加入集群 | 工作节点 |
| `06-cleanup-kubernetes.sh` | 清除Kubernetes集群 | 所有节点 |

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

选择选项 `6` 进行一键安装完整集群，或者按步骤选择：

1. 选择 `1` - 系统环境准备
2. 选择 `2` - 安装控制平面
3. 选择 `3` - 安装Calico网络插件
4. 选择 `4` - 安装Kubernetes Dashboard

### 3. 工作节点加入

在工作节点上运行：

```bash
./00-master-install.sh
```

选择选项 `5` - 工作节点加入集群，然后输入主节点提供的信息。

## 详细安装步骤

### 步骤1: 系统环境准备

在所有节点（主节点和工作节点）上运行：

```bash
./01-prepare-system.sh
```

此脚本会：
- 关闭防火墙和SELinux
- 关闭swap
- 配置内核参数
- 配置阿里云镜像源
- 安装Docker
- 安装Kubernetes组件

### 步骤2: 安装控制平面

仅在主节点上运行：

```bash
./02-install-control-plane.sh
```

此脚本会：
- 初始化Kubernetes控制平面
- 配置kubectl
- 生成工作节点加入命令

### 步骤3: 安装网络插件

仅在主节点上运行：

```bash
./03-install-calico.sh
```

此脚本会：
- 安装Calico网络插件
- 配置Pod网络
- 验证网络连通性

### 步骤4: 安装管理界面

仅在主节点上运行：

```bash
./04-install-dashboard.sh
```

此脚本会：
- 安装Kubernetes Dashboard
- 创建管理员用户
- 生成访问令牌

### 步骤5: 工作节点加入

在工作节点上运行：

```bash
./05-join-worker-node.sh
```

需要输入主节点提供的加入命令信息。

## 验证安装

### 检查集群状态

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### 访问Dashboard

运行以下命令获取访问信息：

```bash
./access-dashboard.sh
```

或者手动获取令牌：

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

## 网络配置

### Pod网络CIDR
默认: `10.244.0.0/16`

### Service网络CIDR
默认: `10.96.0.0/12`

### 控制平面端口
- API Server: 6443
- Dashboard: 30000-32767 (NodePort)

## 故障排除

### 常见问题

1. **节点状态为NotReady**
   - 检查kubelet服务状态: `systemctl status kubelet`
   - 检查Docker服务状态: `systemctl status docker`
   - 检查网络连通性

2. **Pod无法启动**
   - 检查镜像下载: `docker images`
   - 检查网络策略: `kubectl get networkpolicies`
   - 查看Pod日志: `kubectl logs <pod-name>`

3. **Dashboard无法访问**
   - 检查Dashboard Pod状态: `kubectl get pods -n kubernetes-dashboard`
   - 检查Service配置: `kubectl get svc -n kubernetes-dashboard`
   - 检查防火墙设置

### 日志查看

```bash
# 查看kubelet日志
journalctl -u kubelet -f

# 查看Docker日志
journalctl -u docker -f

# 查看Pod日志
kubectl logs <pod-name> -n <namespace>
```

## 清理集群

要完全清除Kubernetes集群，运行：

```bash
./06-cleanup-kubernetes.sh
```

**警告**: 此操作将删除所有Kubernetes数据和配置。

## 配置说明

### 镜像源配置

脚本已配置以下镜像源：
- Kubernetes: 阿里云镜像源
- containerd: 阿里云、中科大、网易、百度镜像源

### 系统配置

- SELinux: permissive模式
- 防火墙: 关闭
- Swap: 关闭
- 内核参数: 已优化

## 安全注意事项

1. 生产环境建议启用防火墙规则
2. 定期更新Kubernetes版本
3. 使用强密码和访问控制
4. 启用RBAC权限控制
5. 定期备份etcd数据

## 版本信息

- Kubernetes版本: v1.28.0
- Calico版本: v3.26.1
- Dashboard版本: v2.7.0
- containerd版本: v1.7.0

## 支持

如果遇到问题，请检查：
1. 系统版本是否为CentOS Stream 10
2. 网络连接是否正常
3. 是否有足够的系统资源
4. 脚本执行权限是否正确

## 许可证

此脚本集遵循MIT许可证。
