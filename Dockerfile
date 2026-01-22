ARG VERSION=2.6.3

# Base layer
FROM 84codes/crystal:latest-alpine AS builder

ARG VERSION
ARG MAKEFLAGS=-j2

RUN apk add build-base curl lz4-dev

WORKDIR /usr/src/lavinmq

ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/shard.yml .
ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/shard.lock .
RUN shards install --production

ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:static ./static
ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:views ./views
ADD https://github.com/cloudamqp/lavinmq.git#v${VERSION}:src ./src

# ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/tags/v${VERSION}/Makefile .
ADD https://raw.githubusercontent.com/cloudamqp/lavinmq/refs/heads/main/Makefile .

RUN make js lib \
    && make all



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
