# Cấu trúc Dockerfile chuẩn
FROM node:20-alpine                     # base image nhỏ
LABEL maintainer="name"                 # metadata
WORKDIR /app                            # working dir
COPY package*.json ./                   # deps files TRƯỚC
RUN npm ci --only=production && \       # install + clean
    npm cache clean --force
COPY . .                                # source code SAU
ENV NODE_ENV=production                 # env defaults
RUN adduser -S appuser && \             # non-root user
    chown -R appuser /app
USER appuser                            # switch user
EXPOSE 3000                             # document port
HEALTHCHECK CMD wget -qO- localhost/health || exit 1
CMD ["node", "server.js"]              # start command