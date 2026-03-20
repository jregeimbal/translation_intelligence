FROM dart:3.11.1 AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY . .
RUN mkdir -p build
RUN dart compile exe bin/server.dart -o build/server

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd --system --create-home appuser

WORKDIR /app

COPY --from=build /runtime/ /runtime/
COPY --from=build /app/build/server /app/server

ENV PORT=8080

USER appuser

EXPOSE 8080

ENTRYPOINT ["/app/server"]
