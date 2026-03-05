# Windows 手动安装与部署指南

本文档说明如何在 Windows 电脑上**手动**安装并部署 infoManage 项目，以及如何将项目打包成 Windows 可执行文件，**无需在目标机器上安装 Go 语言**。

---

## 一、能否打包成 Windows 可执行文件？

**可以。** Go 程序可以编译成**独立的 .exe 文件**，目标电脑**不需要安装 Go**。

- 可执行文件是单文件，包含所有 Go 运行时
- 只需要：`.exe` + `static/` 文件夹 + MySQL 数据库
- 分发时只需复制这些文件到目标电脑即可运行

---

## 二、分发包准备（在能运行 Go 的电脑上执行一次）

如果你有 Go 环境（开发机或 CI），可以预先打包好分发文件。

### 2.1 在 Windows 上打包

在项目目录打开 PowerShell：

```powershell
# 进入项目目录
cd 项目路径\infoManage

# 编译 Windows 64 位可执行文件
go build -o infoManage.exe .

# 分发包需要的文件：
# - infoManage.exe
# - static/ 文件夹（包含 index.html 和 app.js）
```

### 2.2 在 Mac/Linux 上交叉编译（为 Windows 打包）

```bash
# 编译 Windows 64 位版本
GOOS=windows GOARCH=amd64 go build -o infoManage.exe .
```

生成的 `infoManage.exe` 和 `static/` 文件夹就是完整的应用包。

### 2.3 使用项目自带的打包脚本

项目提供一键打包脚本：

```powershell
# Windows PowerShell
.\build-windows.ps1
```

脚本会在 `dist/` 目录生成可分发的文件夹。

---

## 三、目标电脑手动安装步骤

### 步骤 1：安装 MySQL 8.0

1. **下载 MySQL**
   - 官方：https://dev.mysql.com/downloads/mysql/
   - 国内镜像：https://mirrors.aliyun.com/mysql/MySQL-8.0/
   - 选择 Windows (x86, 64-bit) ZIP Archive

2. **解压并安装**
   - 解压到例如 `C:\mysql` 或 `C:\Program Files\MySQL`
   - 以管理员打开 CMD 或 PowerShell，进入 `bin` 目录：
   ```cmd
   cd C:\mysql\bin
   ```
   - 初始化数据目录：
   ```cmd
   mysqld --initialize-insecure --basedir=C:\mysql --datadir=C:\mysql\data
   ```
   - 安装为 Windows 服务：
   ```cmd
   mysqld --install MySQL80
   ```
   - 启动服务：
   ```cmd
   net start MySQL80
   ```

3. **设置 root 密码（首次）**
   ```cmd
   mysql -u root
   ```
   在 MySQL 命令行中执行：
   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootmysql';
   FLUSH PRIVILEGES;
   EXIT;
   ```

---

### 步骤 2：创建数据库

以管理员身份打开 CMD，进入 MySQL 的 `bin` 目录：

```cmd
cd C:\mysql\bin
mysql -u root -prootmysql -e "CREATE DATABASE IF NOT EXISTS infoManage CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

或使用 MySQL 命令行：

```cmd
mysql -u root -p
```

输入密码后执行：

```sql
CREATE DATABASE IF NOT EXISTS infoManage CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

---

### 步骤 3：放置应用文件

将以下内容放到同一目录（例如 `D:\infoManage`）：

```
D:\infoManage\
├── infoManage.exe    # 可执行文件
└── static/           # 静态资源文件夹
    ├── index.html
    └── app.js
```

**重要**：`static` 文件夹必须与 `infoManage.exe` 同目录。

---

### 步骤 4：配置数据库连接

应用通过环境变量连接数据库，默认值如下：

| 环境变量    | 默认值       | 说明           |
|-------------|--------------|----------------|
| DB_USER     | root         | 数据库用户名   |
| DB_PASSWORD | rootmysql    | 数据库密码     |
| DB_HOST     | localhost    | 数据库主机     |
| DB_PORT     | 3306         | 数据库端口     |
| DB_NAME     | infoManage   | 数据库名称     |
| PORT        | 9901         | 应用访问端口   |

#### 方式 A：使用 start.bat 启动（推荐）

在应用目录创建 `start.bat`：

```batch
@echo off
set DB_USER=root
set DB_PASSWORD=rootmysql
set DB_HOST=localhost
set DB_PORT=3306
set DB_NAME=infoManage
set PORT=9901

cd /d "%~dp0"
start "" infoManage.exe

echo 应用已启动，访问 http://localhost:9901
pause
```

双击 `start.bat` 即可启动。

#### 方式 B：在 PowerShell 中设置环境变量后启动

```powershell
$env:DB_USER = "root"
$env:DB_PASSWORD = "rootmysql"
$env:DB_HOST = "localhost"
$env:DB_PORT = "3306"
$env:DB_NAME = "infoManage"
$env:PORT = "9901"

cd D:\infoManage
.\infoManage.exe
```

#### 方式 C：使用系统环境变量

在「此电脑」→ 属性 → 高级系统设置 → 环境变量 中新增：

- `DB_USER` = root  
- `DB_PASSWORD` = 你的MySQL密码  
- `DB_HOST` = localhost  
- `DB_PORT` = 3306  
- `DB_NAME` = infoManage  
- `PORT` = 9901  

然后双击 `infoManage.exe` 或在 CMD 中运行即可。

---

### 步骤 5：启动应用

- 若使用 `start.bat`：双击 `start.bat`
- 若在 PowerShell 中：执行 `.\infoManage.exe`

浏览器访问：**http://localhost:9901**

首次运行时会自动创建数据库表，无需手动执行建表 SQL。

---

### 步骤 6：设置为开机自启（可选）

1. 创建 `start.bat`（如上所示）
2. Win+R → 输入 `shell:startup` 回车
3. 在启动文件夹中创建 `infoManage.vbs`（静默启动，不显示 CMD 窗口）：

```vbscript
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "D:\infoManage\start.bat", 0, False
```

或直接创建快捷方式指向 `start.bat` 放入启动文件夹。

---

## 四、数据库配置说明

### 连接参数对应关系

- **用户名**：`DB_USER`，通常为 `root`
- **密码**：`DB_PASSWORD`，安装 MySQL 时设置的 root 密码
- **主机**：`DB_HOST`，本机用 `localhost` 或 `127.0.0.1`
- **端口**：`DB_PORT`，默认 `3306`
- **数据库名**：`DB_NAME`，固定为 `infoManage`

### 修改数据库配置

如果数据库与默认不同，只需修改启动时的环境变量或 `start.bat` 中的值，例如：

```batch
set DB_PASSWORD=你的实际密码
set DB_PORT=3307
```

### 数据库表

应用首次连接成功后会自动创建以下表：

- crew（船员）
- ship（船舶）
- school（学校）
- company（船公司）
- management（管理公司）

无需手动建表。

---

## 五、常见问题

### 1. 提示「数据库连接失败」

- 检查 MySQL 服务是否已启动：`net start MySQL80` 或 服务管理器中查看
- 确认用户名、密码、端口与环境变量一致
- 确认已创建 `infoManage` 数据库

### 2. 打开网页显示空白或 404

- 确认 `static` 文件夹与 `infoManage.exe` 在同一目录
- 确认 `static` 中有 `index.html` 和 `app.js`

### 3. 端口 9901 被占用

修改 `PORT` 环境变量或 `start.bat` 中的端口，例如改为 9902。

### 4. 目标电脑没有 Go 环境

不需要。只要使用已编译好的 `infoManage.exe`，目标电脑无需安装 Go。

---

## 六、文件清单总结

**分发给用户的最小文件：**

| 文件/目录        | 说明                          |
|------------------|-------------------------------|
| infoManage.exe   | 主程序（约 10–15MB）          |
| static/          | 前端资源（index.html, app.js）|

**用户需自行准备：**

- 已安装并运行的 MySQL 8.0（或 5.7+）
- 已创建的 `infoManage` 数据库
- 启动脚本（如 `start.bat`）或配置好的环境变量

---

## 七、与一键部署脚本的区别

| 方式       | 需要 Go | 需要 MySQL | 自动化程度 |
|------------|---------|------------|------------|
| deploy-windows-native.ps1 | 否（脚本会自动安装） | 否（脚本会自动安装） | 全自动     |
| 本手动方式 | 否      | 是（需手动安装）    | 手动配置   |

若希望完全一键安装（含 Go 和 MySQL），可使用 `deploy-windows-native.ps1`。  
若只需要把应用做成可执行文件分发，按本文档操作即可。
