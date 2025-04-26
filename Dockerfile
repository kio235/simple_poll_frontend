# 阶段1：使用 Node 镜像构建项目
FROM node:20-alpine AS build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# 阶段2：使用 Nginx 镜像部署
FROM nginx:alpine AS production-stage
# 复制构建好的静态文件到 Nginx 目录
COPY --from=build-stage /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]