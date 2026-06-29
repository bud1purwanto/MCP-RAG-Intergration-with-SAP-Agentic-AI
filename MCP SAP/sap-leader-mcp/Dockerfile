# SAP Leader MCP Server — HTTP mode
FROM node:20-slim

WORKDIR /app

# Install deps first for better layer caching
COPY package.json package-lock.json* ./
RUN npm install --omit=optional --omit=dev || npm install --omit=dev

# node-rfc requires the SAP NW RFC SDK + native build toolchain.
# It's an optionalDependency — if unavailable the server runs in SIMULATION MODE automatically.
# To enable LIVE mode, extend this image with the SDK and run:
#   npm install node-rfc
COPY . .

ENV NODE_ENV=production
ENV MCP_HTTP_HOST=0.0.0.0
ENV MCP_HTTP_PORT=8091

EXPOSE 8091

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:'+(process.env.MCP_HTTP_PORT||8091)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "http-server.js"]
