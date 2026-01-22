ARG VERSION=2.6.3

# Base layer
FROM 84codes/crystal:latest-alpine AS base

ARG VERSION

RUN apk add lz4-dev

WORKDIR /usr/src/lavinmq

ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/shard.yml .
ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/shard.lock .
RUN shards install --production

ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:static ./static
ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:views ./views
ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:src ./src



# Run specs on build platform
FROM base AS spec

ARG VERSION
ARG spec_args="--order random"

ADD https://github.com/cloudamqp/lavinmq.git#${VERSION}:spec ./spec

RUN apk add etcd \
    && crystal spec ${spec_args}



# Lint in another layer
FROM base AS lint

ARG VERSION

ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/.ameba.yml .

RUN shards install \
    && bin/ameba \ 
    && crystal tool format --check



# Build
FROM base AS builder

ARG VERSION
ARG MAKEFLAGS=-j2

# ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/Makefile .
ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/heads/main/Makefile .

RUN apk add build-base curl \
    && make js lib \
    && make all



# Resulting image with minimal layers
FROM alpine:latest

ENV GC_UNMAP_THRESHOLD=1
ENV CRYSTAL_LOAD_DEBUG_INFO=1

RUN apk add ca-certificates libstdc++ \
    && rm -rf /var/cache/apk/*

COPY --from=builder /usr/src/lavinmq/bin/* /usr/bin/

COPY --from=ghcr.io/polarix-containers/hardened_malloc:latest /install /usr/local/lib/
ENV LD_PRELOAD="/usr/local/lib/libhardened_malloc.so"

WORKDIR /var/lib/lavinmq

VOLUME /var/lib/lavinmq

EXPOSE 5672 15672

ENTRYPOINT ["/usr/bin/lavinmq", "-b", "0.0.0.0", "--guest-only-loopback=false"]

HEALTHCHECK \
    CMD ["/usr/bin/lavinmqctl", "status"]
