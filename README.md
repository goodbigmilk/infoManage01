# 人员查询系统

一个基于 Go + HTML + MySQL 的数据管理系统，用于管理船员、船舶、学校、船公司和管理公司的信息。

## 功能特性

- ✅ 五个数据对象的管理（船员、船舶、学校、船公司、管理公司）
- ✅ 完整的CRUD操作（增删改查）
- ✅ 关键词搜索功能
- ✅ 详情查看页面
- ✅ 响应式设计，支持移动端
- ✅ 数据库表结构支持后续扩展

## 技术栈

- **后端**: Go 1.21+
- **数据库**: MySQL 5.7+
- **前端**: HTML5 + CSS3 + JavaScript (原生)
- **Web框架**: Gorilla Mux
- **数据库驱动**: go-sql-driver/mysql

## 项目结构

```
infoManage/
├── main.go          # 主程序入口和路由配置
├── database.go      # 数据库表结构定义
├── models.go        # 数据模型和通用函数
├── handlers.go      # API处理函数
├── go.mod           # Go模块依赖
├── static/          # 静态文件目录
│   ├── index.html   # 前端页面
│   └── app.js       # 前端JavaScript逻辑
└── README.md        # 项目说明文档
```

## 安装和运行

### 1. 环境要求

- Go 1.21 或更高版本
- MySQL 5.7 或更高版本

### 2. 安装依赖

```bash
go mod download
```

### 3. 配置数据库

创建MySQL数据库：

```sql
CREATE DATABASE infoManage CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. 配置环境变量（可选）

可以通过环境变量配置数据库连接：

```bash
export DB_USER=root          # 数据库用户名，默认: root
export DB_PASSWORD=          # 数据库密码，默认: 空
export DB_HOST=localhost     # 数据库主机，默认: localhost
export DB_PORT=3306          # 数据库端口，默认: 3306
export DB_NAME=infoManage    # 数据库名称，默认: infoManage
export PORT=8080             # 服务端口，默认: 8080
```

### 5. 运行程序

```bash
go run .
```

或者编译后运行：

```bash
go build -o infoManage
./infoManage
```

### 6. 访问系统

打开浏览器访问：http://localhost:8080

## 数据库表结构

### 船员表 (crew)
- 地区、年龄、学历、毕业学校、状态、职务
- 过往就职船舶、现就职船舶、电话
- 身高、体重、资历、是否科班

### 船舶表 (ship)
- 船龄、船级、所属公司、派员公司
- 主机型号、功率、总吨、载重吨
- 船籍港、船况、工资发放情况

### 学校表 (school)
- 地址、招生电话、级别、其他信息

### 船公司表 (company)
- 地址、拥有船舶、联系电话

### 管理公司表 (management)
- 地址、管理船舶、信誉度、工资发放情况、联系电话

## API接口

### 船员相关
- `GET /api/crew` - 获取船员列表
- `GET /api/crew/{id}` - 获取船员详情
- `POST /api/crew` - 创建船员
- `PUT /api/crew/{id}` - 更新船员
- `DELETE /api/crew/{id}` - 删除船员
- `GET /api/crew/search?keyword=xxx` - 搜索船员

### 船舶相关
- `GET /api/ship` - 获取船舶列表
- `GET /api/ship/{id}` - 获取船舶详情
- `POST /api/ship` - 创建船舶
- `PUT /api/ship/{id}` - 更新船舶
- `DELETE /api/ship/{id}` - 删除船舶
- `GET /api/ship/search?keyword=xxx` - 搜索船舶

### 学校相关
- `GET /api/school` - 获取学校列表
- `GET /api/school/{id}` - 获取学校详情
- `POST /api/school` - 创建学校
- `PUT /api/school/{id}` - 更新学校
- `DELETE /api/school/{id}` - 删除学校
- `GET /api/school/search?keyword=xxx` - 搜索学校

### 船公司相关
- `GET /api/company` - 获取船公司列表
- `GET /api/company/{id}` - 获取船公司详情
- `POST /api/company` - 创建船公司
- `PUT /api/company/{id}` - 更新船公司
- `DELETE /api/company/{id}` - 删除船公司
- `GET /api/company/search?keyword=xxx` - 搜索船公司

### 管理公司相关
- `GET /api/management` - 获取管理公司列表
- `GET /api/management/{id}` - 获取管理公司详情
- `POST /api/management` - 创建管理公司
- `PUT /api/management/{id}` - 更新管理公司
- `DELETE /api/management/{id}` - 删除管理公司
- `GET /api/management/search?keyword=xxx` - 搜索管理公司

## 使用说明

1. **切换Tab**: 点击顶部的5个Tab可以切换不同的数据对象
2. **搜索**: 在搜索框输入关键词，系统会自动搜索相关记录
3. **添加记录**: 点击"添加新记录"按钮，填写表单后保存
4. **查看详情**: 点击表格中的"查看"按钮查看完整信息
5. **编辑记录**: 点击表格中的"编辑"按钮修改记录
6. **删除记录**: 点击表格中的"删除"按钮删除记录（需确认）

## 扩展说明

数据库表结构设计时已考虑扩展性：
- 所有表都有 `created_at` 和 `updated_at` 时间戳字段
- 字段类型选择合理，便于后续添加新字段
- 已建立必要的索引以提高查询性能

如需添加新字段：
1. 修改 `database.go` 中的表结构定义
2. 更新 `models.go` 中的模型结构
3. 更新 `handlers.go` 中的查询和更新语句
4. 更新 `static/app.js` 中的字段配置

## 注意事项

- 首次运行时会自动创建数据库表
- 确保MySQL服务已启动
- 确保数据库用户有创建表的权限
- 建议在生产环境中配置HTTPS和身份验证

## 许可证

MIT License
