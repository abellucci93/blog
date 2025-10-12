FROM hugomods/hugo:exts-non-root-0.147.8 AS base
COPY . /src

FROM base AS dev
CMD ["server", "--bind", "0.0.0.0", "--buildDrafts"]

FROM base AS build

USER root
RUN mkdir -p /tmp/build \
    && hugo build --destination /tmp/build

FROM nginx:1.29.2-alpine3.22 AS production
COPY --from=build --link /tmp/build /usr/share/nginx/html

