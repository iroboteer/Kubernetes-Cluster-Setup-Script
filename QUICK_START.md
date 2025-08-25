# 快速开始指南

## 解决 "kubeadm: command not found" 错误

您遇到的错误是因为系统还没有安装Kubernetes组件。请按以下步骤操作：

### 方法1: 使用诊断脚本（推荐）

```bash
# 运行诊断脚本查看问题
./fix-installation.sh
```

### 方法2: 手动解决

1. **首先运行系统环境准备**：
   ```bash
   ./01-prepare-system.sh
   ```

2. **然后安装控制平面**：
   ```bash
   ./02-install-control-plane.sh
   ```

### 方法3: 使用主控制脚本

```bash
# 运行主控制脚本
./00-master-install.sh

# 选择选项 9 进行诊断
# 或者选择选项 6 进行一键安装
```

## 完整的安装流程

### 在主节点上：

1. **系统环境准备**（所有节点都需要）：
   ```bash
   ./01-prepare-system.sh
   ```

2. **安装控制平面**：
   ```bash
   ./02-install-control-plane.sh
   ```

3. **安装网络插件**：
   ```bash
   ./03-install-calico.sh
   ```

4. **安装管理界面**：
   ```bash
   ./04-install-dashboard.sh
   ```

### 在工作节点上：

1. **系统环境准备**：
   ```bash
   ./01-prepare-system.sh
   ```

2. **加入集群**：
   ```bash
   ./05-join-worker-node.sh
   ```

## 一键安装（推荐）

在主节点上运行：
```bash
./00-master-install.sh
```
选择选项 `6` 进行一键安装。

## 常见问题解决

### 1. 权限问题
确保以root用户身份运行所有脚本：
```bash
sudo su -
```

### 2. 网络问题
确保所有节点之间网络连通：
```bash
ping <其他节点IP>
```

### 3. 系统要求
- CentOS Stream 10
- 至少2GB RAM
- 至少2个CPU核心
- 至少20GB磁盘空间

### 4. 防火墙设置
脚本会自动关闭防火墙，但如果您需要保持防火墙开启，请手动配置以下端口：
- 6443 (API Server)
- 10250 (Kubelet)
- 30000-32767 (NodePort Services)

## 验证安装

安装完成后，运行以下命令验证：

```bash
# 检查节点状态
kubectl get nodes

# 检查Pod状态
kubectl get pods --all-namespaces

# 检查服务状态
kubectl get services --all-namespaces
```

## 访问Dashboard

```bash
# 获取访问信息
./access-dashboard.sh
```

## 获取帮助

如果遇到问题，请运行：
```bash
./fix-installation.sh
```

或者查看详细文档：
```bash
cat README.md
```
