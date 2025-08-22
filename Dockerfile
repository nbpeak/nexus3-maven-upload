# 统一的 Dockerfile - 构建前端并运行后端服务
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 复制前端项目文件
COPY frontend/package*.json ./frontend/
COPY frontend/ ./frontend/

# 构建前端
WORKDIR /app/frontend
RUN npm install
RUN npm run build

# 回到根目录，设置后端
WORKDIR /app
COPY backend/package*.json ./
RUN npm install

# 复制后端代码
COPY backend/ ./

# 将前端构建文件复制到后端的public目录
RUN cp -r ./frontend/dist/* ./public/

# 清理前端文件节省空间
RUN rm -rf ./frontend

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["npm", "start"]