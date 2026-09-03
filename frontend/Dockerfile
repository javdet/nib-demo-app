# syntax=docker/dockerfile:1

# ---------------------------------------------------------------- build ----
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig*.json vite.config.ts index.html ./
COPY public ./public
COPY src ./src

ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# ---------------------------------------------------------------- serve ----
# In AWS this stage is not deployed: `dist/` is synced to S3 and served by
# CloudFront. It exists so the compose stack behaves the same way locally,
# including the /api/* routing that CloudFront does at the edge.
FROM nginxinc/nginx-unprivileged:1.27-alpine AS serve

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /docker-entrypoint.d/99-runtime-config.sh

# The bundle is copied in as root; the runtime config is rewritten at boot by
# the unprivileged nginx user, so the html directory has to belong to it.
USER root
RUN chmod +x /docker-entrypoint.d/99-runtime-config.sh \
    && chown -R nginx:nginx /usr/share/nginx/html
USER nginx

EXPOSE 8080

# The base image entrypoint runs everything in /docker-entrypoint.d first.
CMD ["nginx", "-g", "daemon off;"]
