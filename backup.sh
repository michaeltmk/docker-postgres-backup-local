#! /bin/sh

set -e
#####################local######################
if [ "${POSTGRES_DB}" = "**None**" -a "${POSTGRES_DB_FILE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DB or POSTGRES_DB_FILE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=${POSTGRES_PORT_5432_TCP_ADDR}
    POSTGRES_PORT=${POSTGRES_PORT_5432_TCP_PORT}
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" -a "${POSTGRES_USER_FILE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER or POSTGRES_USER_FILE environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" -a "${POSTGRES_PASSWORD_FILE}" = "**None**" -a "${POSTGRES_PASSFILE_STORE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE or POSTGRES_PASSFILE_STORE environment variable or link to a container named POSTGRES."
  exit 1
fi

#Process vars
if [ "${POSTGRES_DB_FILE}" = "**None**" ]; then
  POSTGRES_DBS=$(echo "${POSTGRES_DB}" | tr , " ")
elif [ -r "${POSTGRES_DB_FILE}" ]; then
  POSTGRES_DBS=$(cat "${POSTGRES_DB_FILE}")
else
  echo "Missing POSTGRES_DB_FILE file."
  exit 1
fi
if [ "${POSTGRES_USER_FILE}" = "**None**" ]; then
  export PGUSER="${POSTGRES_USER}"
elif [ -r "${POSTGRES_USER_FILE}" ]; then
  export PGUSER=$(cat "${POSTGRES_USER_FILE}")
else
  echo "Missing POSTGRES_USER_FILE file."
  exit 1
fi
if [ "${POSTGRES_PASSWORD_FILE}" = "**None**" -a "${POSTGRES_PASSFILE_STORE}" = "**None**" ]; then
  export PGPASSWORD="${POSTGRES_PASSWORD}"
elif [ -r "${POSTGRES_PASSWORD_FILE}" ]; then
  export PGPASSWORD=$(cat "${POSTGRES_PASSWORD_FILE}")
elif [ -r "${POSTGRES_PASSFILE_STORE}" ]; then
  export PGPASSFILE="${POSTGRES_PASSFILE_STORE}"
else
  echo "Missing POSTGRES_PASSWORD_FILE or POSTGRES_PASSFILE_STORE file."
  exit 1
fi
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

#Initialize dirs
mkdir -p "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Loop all databases
for DB in ${POSTGRES_DBS}; do
  #Initialize filename vers
  DFILE="${BACKUP_DIR}/daily/${DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
  WFILE="${BACKUP_DIR}/weekly/${DB}-`date +%G%V`${BACKUP_SUFFIX}"
  MFILE="${BACKUP_DIR}/monthly/${DB}-`date +%Y%m`${BACKUP_SUFFIX}"
  #Create dump
  if [ "${POSTGRES_CLUSTER}" = "TRUE" ]; then
    echo "Creating cluster dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dumpall -l "${DB}" ${POSTGRES_EXTRA_OPTS} | gzip -9 > "${DFILE}"
  else
    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump -d "${DB}" -f "${DFILE}" ${POSTGRES_EXTRA_OPTS}
  fi
  #Copy (hardlink) for each entry
  if [ -d "${DFILE}" ]; then
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${WFILENEW}" "${MFILENEW}"
    mkdir "${WFILENEW}" "${MFILENEW}"
    ln -f "${DFILE}/"* "${WFILENEW}/"
    ln -f "${DFILE}/"* "${MFILENEW}/"
    rm -rf "${WFILE}" "${MFILE}"
    mv -v "${WFILENEW}" "${WFILE}"
    mv -v "${MFILENEW}" "${MFILE}"
  else
    ln -vf "${DFILE}" "${WFILE}"
    ln -vf "${DFILE}" "${MFILE}"
  fi
  #Clean old files
  echo "Cleaning older than ${KEEP_DAYS} days for ${DB} database from ${POSTGRES_HOST}..."
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime +${KEEP_DAYS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime +${KEEP_WEEKS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime +${KEEP_MONTHS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
done

######################AWS###################
set -o pipefail

if [ "${S3_ENABLE}" = "yes" ]; then

  if [ "${S3_S3V4}" = "yes" ]; then
      aws configure set default.s3.signature_version s3v4
  fi

  if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
    echo "You need to set the S3_ACCESS_KEY_ID environment variable."
    exit 1
  fi

  if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
    echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
    exit 1
  fi

  if [ "${S3_BUCKET}" = "**None**" ]; then
    echo "You need to set the S3_BUCKET environment variable."
    exit 1
  fi

  if [ "${S3_ENDPOINT}" == "**None**" ]; then
    AWS_ARGS=""
  else
    AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
  fi

  # env vars needed for aws tools
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
  export AWS_DEFAULT_REGION=$S3_REGION

  aws $AWS_ARGS s3 sync $BACKUP_DIR s3://$S3_BUCKET/$S3_PATH || exit 2

fi




echo "SQL backup created successfully"
