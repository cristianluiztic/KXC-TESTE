FROM node:18-alpine

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm install --only=production

COPY src ./src

# FIX: criar usuário não-root e transferir ownership dos arquivos
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

# FIX: executar como usuário não-privilegiado (não mais root)
USER appuser

EXPOSE 3000

CMD ["npm", "start"]
