# Nexus3 Deploy - Maven Artifact Uploader

一个统一的Node.js应用，用于上传本地JAR包到远程Maven仓库（如Nexus）。

项目代码由AI完成

## 功能特性

- 🎯 **自动解析**：自动从JAR包中解析pom.xml获取坐标信息
- 🖥️ **Web界面**：简洁易用的Web界面
- 📦 **批量上传**：支持拖拽多个JAR文件批量上传
- ⚡ **统一部署**：前后端合并，单一Node.js进程运行
- 💾 **配置保存**：Nexus服务器配置自动保存到浏览器本地存储
- 🔄 **智能SNAPSHOT处理**：自动为SNAPSHOT版本生成时间戳

## 快速开始

### 方式一：使用启动脚本（推荐）
```bash
./start.sh
```

### 方式二：手动启动
```bash
cd backend
npm install
npm start
```

### 方式三：Docker单容器部署（推荐生产环境）
```bash
docker-compose up --build
```

### 方式四：Docker分离部署（旧方式，仍可用）
如需使用原来的前后端分离部署方式，可以恢复原来的docker-compose配置。

启动后访问：
- **统一应用**：http://localhost:3000
- **Docker单容器**：http://localhost:3000
- **Docker分离方式**：http://localhost:8080

## 使用说明

1. **配置Nexus服务器**：填写Nexus URL、仓库名、用户名和密码
2. **选择JAR文件**：拖拽或点击选择要上传的JAR文件
3. **确认信息**：系统会自动解析JAR包中的pom.xml并回填坐标信息
4. **批量上传**：点击"Upload All"开始上传

## 技术栈

- **后端**：Node.js + Express 4.x
- **前端**：Vue.js 3 + Vite
- **依赖**：
  - adm-zip: JAR文件解析
  - xml2js: XML解析
  - axios: HTTP请求
  - multer: 文件上传

## 项目结构

```
nexus3-deploy/
├── backend/
│   ├── server.js          # 主服务器文件（统一应用）
│   ├── package.json       # 依赖配置
│   └── public/            # 前端构建文件
├── frontend/              # 前端源码（开发时使用）
├── start.sh               # 统一启动脚本
├── docker-compose.yml     # Docker部署配置
└── README.md
```

## 部署方式对比

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| 统一Node.js | 部署简单，资源占用少 | 需要Node.js环境 | 开发、测试、小型部署 |
| Docker单容器 | 环境隔离，部署简单，资源占用适中 | 需要Docker环境 | 生产环境推荐 |
| Docker分离 | 微服务架构，可独立扩展 | 资源占用多，配置复杂 | 大型分布式部署 |

## 注意事项

- 确保Node.js版本 >= 16
- 首次运行会自动安装依赖
- 配置信息会保存在浏览器本地存储中
- 统一应用模式下，前后端共享同一端口（3000）
