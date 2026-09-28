FROM node:22-bookworm

RUN npm install -g @xai-official/grok

WORKDIR /app
COPY server/package.json ./package.json
COPY server/index.js ./index.js

ENV NODE_ENV=production
ENV PORT=8787
ENV GROK_HOME=/data/.grok

RUN mkdir -p /data/.grok

VOLUME ["/data"]

EXPOSE 8787

CMD ["node", "index.js"]
