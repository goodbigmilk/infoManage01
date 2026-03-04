# Windows 部署方案选择指南

## 两种部署方案

本项目提供两种 Windows 部署方案，请根据你的情况选择：

## 方案 1: Docker 部署 ⚡（推荐给有经验的用户）

### 使用文件
- `deploy.bat` / `deploy.ps1`

### 适用场景
- ✅ 已经安装了 Docker Desktop
- ✅ 需要跨平台部署（开发/生产环境一致）
- ✅ 熟悉容器技术
- ✅ 有国际网络访问

### 优点
- 环境隔离，不影响系统
- 跨平台一致性
- 易于迁移和扩展
- 一键清理（不留痕迹）

### 缺点
- ❌ 需要安装 Docker Desktop（约 500MB）
- ❌ 需要启用 WSL2（占用资源）
- ❌ 初次下载镜像较慢
- ❌ 占用内存较多

### 快速使用
```cmd
右键 deploy.bat → 以管理员身份运行
```

---

## 方案 2: Windows 原生部署 🚀（推荐给国内用户）

### 使用文件
- `deploy-native.bat` / `deploy-windows-native.ps1`

### 适用场景
- ✅ **不想安装 Docker**
- ✅ **国内网络环境**（使用国内镜像源）
- ✅ 想要更快的启动速度
- ✅ 想要更低的资源占用
- ✅ 简单的个人使用

### 优点
- ✅ **无需 Docker 和 WSL**
- ✅ **使用国内镜像，下载快**
- ✅ 启动速度快
- ✅ 资源占用低
- ✅ 原生 Windows 服务

### 缺点
- ❌ 仅支持 Windows
- ❌ 会在系统安装 Go 和 MySQL
- ❌ 卸载需要手动清理

### 快速使用
```cmd
右键 deploy-native.bat → 以管理员身份运行
```

---

## 快速对比表

| 特性 | Docker 版本 | 原生版本 |
|------|------------|----------|
| **是否需要 Docker** | ✅ 需要 | ❌ 不需要 |
| **是否需要 WSL** | ✅ 需要 | ❌ 不需要 |
| **首次安装大小** | ~500MB | ~200MB |
| **启动速度** | 较慢（30-60秒） | 快（5-10秒） |
| **内存占用** | 高（~1GB） | 低（~200MB） |
| **国内网络友好** | ❌ 一般 | ✅ 优化 |
| **卸载干净度** | ✅ 完全 | ⚠️ 需手动 |
| **跨平台** | ✅ 是 | ❌ 仅 Windows |
| **适合新手** | ❌ 较难 | ✅ 简单 |

---

## 推荐选择

### 👉 选择原生版本，如果你：
- 在中国大陆，没有梯子
- 不想安装 Docker（太复杂）
- 只是个人使用，不需要跨平台
- 想要快速启动和低资源占用

**使用**: `deploy-native.bat`

### 👉 选择 Docker 版本，如果你：
- 已经安装了 Docker
- 需要开发和生产环境一致
- 需要快速部署到多台服务器
- 熟悉容器技术

**使用**: `deploy.bat`

---

## 快速开始（原生版本）

1. **下载项目**
   ```bash
   git clone https://github.com/goodbigmilk/infoManage01.git
   cd infoManage01
   ```

2. **右键以管理员身份运行**
   ```
   右键 deploy-native.bat → 以管理员身份运行
   ```

3. **等待安装完成**
   - 自动下载 Go（~100MB）
   - 自动下载 MySQL（~100MB）
   - 自动编译和启动

4. **打开浏览器访问**
   ```
   http://localhost:9901
   ```

**就这么简单！** 🎉

---

## 详细文档

- **Docker 部署**: 查看 `README.md`
- **原生部署**: 查看 `WINDOWS_NATIVE_DEPLOY.md`

## 常见问题

### Q: 我应该选哪个？
**A**: 如果你不确定，选择**原生版本** (`deploy-native.bat`)，更简单！

### Q: 两个可以同时安装吗？
**A**: 可以，但会端口冲突。建议只用一个。

### Q: 如何切换？
**A**:
- Docker → 原生: 先运行 `deploy.bat stop`，再运行 `deploy-native.bat`
- 原生 → Docker: 先运行 `deploy-native.bat stop`，再运行 `deploy.bat`

### Q: 数据会丢失吗？
**A**: 两个版本使用不同的数据库，互不影响。

---

## 需要帮助？

- GitHub Issues: https://github.com/goodbigmilk/infoManage01/issues
- 查看详细文档: `WINDOWS_NATIVE_DEPLOY.md`

---

**提示**: 首次使用推荐选择 **原生版本** (`deploy-native.bat`) ⭐
