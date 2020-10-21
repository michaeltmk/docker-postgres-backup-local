ARG BASETAG=latest
FROM postgres:$BASETAG

ARG GOCRONVER=v0.0.9
ARG TARGETOS
ARG TARGETARCH
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
	&& curl -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH.gz | zcat > /usr/local/bin/go-cron \
	&& chmod a+x /usr/local/bin/go-cron

# install s3 tools
RUN apt install python python3-pip -y
RUN pip3 install awscli
RUN apt-get purge -y --auto-remove ca-certificates python3-pip curl && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV POSTGRES_DB="**None**" \
    POSTGRES_DB_FILE="**None**" \
    POSTGRES_HOST="**None**" \
    POSTGRES_PORT=5432 \
    POSTGRES_USER="**None**" \
    POSTGRES_USER_FILE="**None**" \
    POSTGRES_PASSWORD="**None**" \
    POSTGRES_PASSWORD_FILE="**None**" \
    POSTGRES_PASSFILE_STORE="**None**" \
    POSTGRES_EXTRA_OPTS="-Z9" \
    POSTGRES_CLUSTER="FALSE" \
    SCHEDULE="@daily" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".sql.gz" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    HEALTHCHECK_PORT=8080

ENV S3_ENABLE=no \
    S3_ACCESS_KEY_ID=**None** \
    S3_SECRET_ACCESS_KEY=**None** \
    S3_BUCKET=**None** \
    S3_REGION=us-west-1 \
    S3_PATH='backup' \
    S3_ENDPOINT=**None** \
    S3_S3V4=no

COPY backup.sh /backup.sh

VOLUME /backups

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/go-cron -s \"$SCHEDULE\" -p \"$HEALTHCHECK_PORT\" -- /backup.sh"]

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1
