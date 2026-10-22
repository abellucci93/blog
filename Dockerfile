FROM hugomods/hugo:exts-non-root-0.147.8 AS base
COPY . /src

FROM base AS dev
CMD ["server", "--bind", "0.0.0.0", "--buildDrafts", "--buildFuture"]

FROM base AS build

USER root
RUN mkdir -p /tmp/build \
    && hugo build --destination /tmp/build

FROM nginx:1.31.8-alpine3.24-slim AS production
COPY --from=build --link /tmp/build /usr/share/nginx/html

