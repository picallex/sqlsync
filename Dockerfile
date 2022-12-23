FROM crystallang/crystal:1.4.0-alpine

RUN apk add sqlite-dev sqlite-static
RUN apk add libpq
