# DeepSeek AI Assistant 阿里云服务器部署方案

## 项目概述

- **后端**: FastAPI + SQLAlchemy + SQLite (可升级 PostgreSQL)
- **前端**: Flutter Web
- **部署方式**: Docker 容器化 + GitHub Actions CI/CD

---

## 一、服务器准备 (阿里云 Ubuntu)

### 1.1 服务器要求
- **操作系统**: Ubuntu 22.04 LTS 或更高版本
- **配置建议**: 2核4G 内存起步 (推荐 4核8G)
- **安全组开放端口**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8000 (后端 API)

### 1.2 安装 Docker 和 Docker Compose

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo apt install docker-compose-plugin -y

# 验证安装
docker --version
docker compose version
```

---

## 二、项目 Docker 配置

### 2.1 后端 Dockerfile

创建文件: `backend/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制应用代码
COPY . .

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 2.2 前端 Dockerfile

创建文件: `deepseek_assistant/Dockerfile`

```dockerfile
# 构建阶段
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# 复制依赖文件
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 复制源代码
COPY . .

# 构建 Web 版本
RUN flutter build web --release

# 运行阶段
FROM nginx:alpine

# 复制构建产物
COPY --from=builder /app/build/web /usr/share/nginx/html

# 复制 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 2.3 前端 Nginx 配置

创建文件: `deepseek_assistant/nginx.conf`

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Flutter Web 路由配置
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理到后端
    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 2.4 Docker Compose 配置

创建文件: `docker-compose.yml` (项目根目录)

```yaml
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: deepseek-backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data  # 持久化数据库
    environment:
      - DATABASE_URL=sqlite:///./data/chat_db.sqlite
      - SECRET_KEY=${SECRET_KEY}
      - REFRESH_SECRET_KEY=${REFRESH_SECRET_KEY}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
    networks:
      - deepseek-network

  frontend:
    build:
      context: ./deepseek_assistant
      dockerfile: Dockerfile
    container_name: deepseek-frontend
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - deepseek-network

networks:
  deepseek-network:
    driver: bridge
```

### 2.5 环境变量配置

创建文件: `.env` (项目根目录)

```bash
# 后端密钥 (请替换为随机生成的强密钥)
SECRET_KEY=your-super-secret-key-here
REFRESH_SECRET_KEY=your-refresh-secret-key-here

# 邮件配置
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

---

## 三、GitHub Actions CI/CD 配置

### 3.1 创建 GitHub Secrets

在 GitHub 仓库的 Settings > Secrets and variables > Actions 中添加:

| Secret 名称 | 说明 |
|---|---|
| `SERVER_HOST` | 服务器 IP 地址 |
| `SERVER_USERNAME` | SSH 用户名 (通常是 root) |
| `SERVER_SSH_KEY` | SSH 私钥内容 |
| `SECRET_KEY` | 后端 JWT 密钥 |
| `REFRESH_SECRET_KEY` | 后端 Refresh Token 密钥 |
| `SMTP_USER` | 邮箱地址 |
| `SMTP_PASSWORD` | 邮箱应用密码 |

### 3.2 GitHub Actions 工作流

创建文件: `.github/workflows/deploy.yml`

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt

      - name: Run tests (if any)
        run: echo "Tests passed"

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USERNAME }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            cd /opt/deepseek-assistant

            # 拉取最新代码
            git pull origin main

            # 创建环境变量文件
            cat > .env << EOF
            SECRET_KEY=${{ secrets.SECRET_KEY }}
            REFRESH_SECRET_KEY=${{ secrets.REFRESH_SECRET_KEY }}
            SMTP_USER=${{ secrets.SMTP_USER }}
            SMTP_PASSWORD=${{ secrets.SMTP_PASSWORD }}
            EOF

            # 重新构建并启动容器
            docker compose down
            docker compose build --no-cache
            docker compose up -d

            # 清理旧镜像
            docker image prune -f

            echo "Deployment completed successfully!"
```

---

## 四、服务器初始化部署步骤

### 4.1 首次部署

```bash
# 1. SSH 登录服务器
ssh root@your-server-ip

# 2. 克隆项目
cd /opt
git clone https://github.com/your-username/your-repo.git deepseek-assistant
cd deepseek-assistant

# 3. 配置环境变量
cp .env.example .env
nano .env  # 编辑填入实际值

# 4. 创建数据目录
mkdir -p data

# 5. 构建并启动
docker compose build
docker compose up -d

# 6. 查看运行状态
docker compose ps
docker compose logs -f
```

### 4.2 配置域名和 SSL (推荐)

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 申请 SSL 证书
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# 自动续期测试
sudo certbot renew --dry-run
```

### 4.3 更新 Nginx 配置支持 HTTPS

修改 `deepseek_assistant/nginx.conf`:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 五、Flutter 前端适配

### 5.1 修改 API 配置

部署时需要将 API 地址改为相对路径。修改 `deepseek_assistant/lib/core/config/app_config.dart`:

```dart
class AppConfig {
  // 生产环境使用相对路径，通过 Nginx 代理
  static const String backendApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',  // 相对路径，由 Nginx 代理
  );
  // ... 其他配置
}
```

### 5.2 构建时传入环境变量

修改 `deepseek_assistant/Dockerfile`:

```dockerfile
# 构建阶段
RUN flutter build web --release \
    --dart-define=API_BASE_URL=/api
```

---

## 六、常用运维命令

```bash
# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f backend
docker compose logs -f frontend

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 进入容器调试
docker exec -it deepseek-backend /bin/bash

# 备份数据库
cp data/chat_db.sqlite backup/chat_db_$(date +%Y%m%d).sqlite

# 恢复数据库
docker compose down
cp backup/chat_db_20240101.sqlite data/chat_db.sqlite
docker compose up -d
```

---

## 七、监控和维护

### 7.1 设置自动备份

创建 `/opt/deepseek-assistant/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/deepseek"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
cp /opt/deepseek-assistant/data/chat_db.sqlite $BACKUP_DIR/chat_db_$DATE.sqlite

# 保留最近 30 天的备份
find $BACKUP_DIR -name "*.sqlite" -mtime +30 -delete
```

添加定时任务:

```bash
crontab -e
# 每天凌晨 3 点备份
0 3 * * * /opt/deepseek-assistant/backup.sh
```

### 7.2 日志轮转

创建 `/etc/logrotate.d/deepseek`:

```
/var/log/deepseek/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## 八、部署检查清单

- [ ] 服务器 Docker 和 Docker Compose 已安装
- [ ] GitHub Secrets 已配置
- [ ] `.env` 文件已创建并填入正确的密钥
- [ ] 域名已解析到服务器 IP (如有)
- [ ] SSL 证书已配置 (推荐)
- [ ] 防火墙/安全组已开放端口 80, 443
- [ ] 数据库备份策略已设置
- [ ] GitHub Actions 工作流已创建

---

## 九、故障排查

### 问题: 容器无法启动
```bash
docker compose logs backend
docker compose logs frontend
```

### 问题: 数据库连接失败
```bash
# 检查数据目录权限
ls -la data/
chmod 755 data/
```

### 问题: CORS 错误
确保后端 `CORS_ORIGINS` 包含前端域名

### 问题: API 请求 404
检查 Nginx 代理配置和前端 API 路径

---

**部署完成后访问**: http://your-server-ip 或 https://your-domain.com
