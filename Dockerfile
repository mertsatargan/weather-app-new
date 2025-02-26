# Stage 1: Build (Vite için)
FROM --platform=linux/amd64 node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build  

# Stage 2: Serve with Nginx
FROM --platform=linux/amd64 nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html  
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]