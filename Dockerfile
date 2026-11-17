FROM ghcr.io/cirruslabs/flutter:3.50.0 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY . .
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY
ARG SUPABASE_AUTH_REDIRECT_URL
RUN flutter build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define="SUPABASE_AUTH_REDIRECT_URL=${SUPABASE_AUTH_REDIRECT_URL}"

FROM nginxinc/nginx-unprivileged:stable-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
