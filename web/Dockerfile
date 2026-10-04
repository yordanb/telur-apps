# syntax=docker/dockerfile:1

# ---- build ----
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG VITE_API_URL=https://egg.mibt.my.id/api
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# ---- serve ----
FROM nginx:alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
