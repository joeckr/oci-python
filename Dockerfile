ARG IMAGE=nginx
ARG TAG=1.31.5-alpine
ARG REGISTRY=docker.io/library
FROM $REGISTRY/$IMAGE:$TAG

ARG VERSION=1.31.5

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /tmp/nginx/logs /tmp/nginx/client /tmp/nginx/fastcgi /tmp/nginx/proxy /tmp/nginx/scgi /tmp/nginx/uwsgi && \
    chgrp -R 0 /tmp/nginx /var/cache/nginx && \
    chmod -R g+rwX /tmp/nginx /var/cache/nginx

WORKDIR /app

RUN chgrp -R 0 /app && \
    chmod -R g+rwX /app

EXPOSE 8080

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "nginx", "-g", "daemon off;" ]

USER 1031
