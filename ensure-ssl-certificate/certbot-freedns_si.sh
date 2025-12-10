#!/bin/bash

# Description:
#  Script for updating TXT DNS record at freedns.si for the purpose to be
#  used by Certbot.
#
#  The base idea behind this script sources back to Anthony Wharton and his
#  initial work for using CertBot with FreeDNS.afraid.org.
#  Anthony released his work under 'nthony Wharton,Copyright 2018', whatever
#  it is.
#
#  I'm releasing all modification completely free and publically available.

# Global vatiables
ROOT_URL="https://www.freedns.si"
AUTH_FILENAME="_auth_credentials.inc"
ACME_NAME_PREFIX="_acme-challenge"
COOKIEFILE=$(mktemp)

# Runtime
REGEX_RECORD_ID="s/.*\/\([0-9]*\).*/\1/"
WORKING_DIR=$(dirname $0)

#
# -- Helper functions --
#

# Program usage
function PrintHelp() {
  cat << _EOF_
Usage:
  $0 --auth | --cleanup

Details:
 Please note the scripts expects a '${AUTH_FILENAME}' to exist in the script directlry. Mentioned
 file should set following variables to correct values - you can find an example below, between the
 two '----' lines:
 ----
 USERNAME="freedns.si username"
 PASSWORD="freedns.si password"
 DOMAIN="domain need managing
 ----
_EOF_
  exit 1
}

# Logs in and acquires the auth cookie needed for future calls
# args: <cookie_filename_to_create>
function ApiLogin() {
  local _COOKIEFILE="$1"
  echo "Logging in..."
  echo -n "  "
  curl -s ${ROOT_URL}/user/checklogin \
    -X POST \
    -c ${_COOKIEFILE} \
    -d "username=${USERNAME}" -d "password=${PASSWORD}"
  echo ""
  if [ $? -ne 0 ]; then
    echo "ERROR: Operation failed! Exiting ..."
    rm -f ${_COOKIEFILE}
    exit 1
  fi
}

# Fetch domain ID for passed DNS domain and return it as specified variable name.
# args: <var_name_to_fill_with_domain_ID> <cookie_file> <domain_name>
function FetchDomainId() {
  local _DOM_ID_VAR_NAME="$1"
  local _COOKIEFILE="$2"
  local _DOMAIN="$3"
  echo "Fetching domain ID..."
  local _DOM_ID=$(
    curl -s "${ROOT_URL}/domain" -X GET -b ${_COOKIEFILE} 2> /dev/null |
      xmllint --html --xpath "//td[contains(text(), '${_DOMAIN}')]/following-sibling::td[1]/a/@href" - 2> /dev/null |
      sed -e ${REGEX_RECORD_ID}
  )
  eval ${_DOM_ID_VAR_NAME}=${_DOM_ID}
}

# Fetch passed TXT record ID.
# NOTE: the record search isn't super reliable - in case multiple (similar) records exists, ID of the first one is returned :)
# args: <var_name_to_fill_with_record_ID> <cookie_file> <domain_ID> <hostname>
function FindTxtRecordId() {
  local _RECORD_ID_VAR_NAME="$1"
  local _COOKIEFILE="$2"
  local _DOM_ID="$3"
  local _HOSTNAME="$4"
  echo "Fetching TXT record ID (if existent)..."
  local _RECORD_ID=$(
    curl -s "${ROOT_URL}/record/index/domain-id/${_DOM_ID}/search/?search=${_HOSTNAME}" \
      -X GET -b ${_COOKIEFILE} |
      xmllint --html --xpath "//td/span[contains(text(), 'TXT')]/parent::td/following-sibling::td[5]/a/@href" - 2> /dev/null |
      tail -1 |
      sed -e ${REGEX_RECORD_ID}
  )
  eval ${_RECORD_ID_VAR_NAME}=${_RECORD_ID}
}

# Create a TXT record.
# args: <cookie_file> <domain_ID> <record_ID> <domain_host> <record_value>
function CreateTxtRecord() {
  local _COOKIEFILE="$1"
  local _DOM_ID="$2"
  local _RECORD_ID="$3"
  local _DOMAIN_HOST="$4"
  local _RECORD_VALUE="$5"

  echo "Creating/Updaing TXT record '${_DOMAIN_HOST}' ..."
  local _API_URL="${ROOT_URL}/record/edit/domain-id/${_DOM_ID}"
  if [ ! -z "${_RECORD_ID}" ]; then
    _API_URL="${_API_URL}/search//record-id/${_RECORD_ID}/"
  else
    _API_URL="${ROOT_URL}/record/add/domain-id/${_DOM_ID}"
  fi
  curl -s "${_API_URL}" \
    -X POST \
    -b ${_COOKIEFILE} \
    -d "domainid=${_DOM_ID}" \
    -d "recordid=${_RECORD_ID}" \
    -d "type=TXT" \
    -d "name=${_DOMAIN_HOST}" \
    -d "content=%22${_RECORD_VALUE}%22" \
    -d "prio=0" \
    -d "ttl=3600" \
    -d "save=Shrani"
  if [ $? -ne 0 ]; then
    echo "ERROR: Operation failed! Exiting ..."
    rm -f ${_COOKIEFILE}
    exit 2
  fi
  echo "  DONE"
}

# Delete specified record.
# args: <cookie_file> <domain_ID> <record_ID>
function DeleteTxtRecord() {
  local _COOKIEFILE="$1"
  local _DOM_ID="$2"
  local _RECORD_ID="$3"

  echo "Deleting record having ID: '${_RECORD_ID}' ..."
  curl -s "${ROOT_URL}/record/delete/domain-id/${_DOM_ID}/record-id/${_RECORD_ID}" \
    -X GET \
    -b ${_COOKIEFILE}
  if [ $? -ne 0 ]; then
    echo "ERROR: Operation failed! Exiting ..."
    rm -f ${_COOKIEFILE}
    exit 2
  fi
  echo "  DONE"
}

#
# -- Main program --
#

# Check script arguments and mandatory variables
if [ $# -ne 1 ]; then
  echo "ERROR: Incorrect invocation! Try with --help. Exiting ..."
  exit 1
fi

OP=""
case "$1" in
--help)
  PrintHelp
  exit 1
  ;;
--auth)
  OP="auth"
  ;;
--cleanup)
  OP="cleanup"
  ;;
*)
  echo "ERROR: Incorrect invocation! Try with --help. Exiting ..."
  exit 1
  ;;
esac

if [ ! -f "${WORKING_DIR}/${AUTH_FILENAME}" ]; then
  echo "ERROR: Missing credentials file! Exiting ..."
  exit 1
fi
source ${WORKING_DIR}/${AUTH_FILENAME}
if [ -z "${USERNAME}" -o -z "${PASSWORD}" -o -z "${DOMAIN}" ]; then
  echo "ERROR: One of mandatory variables USERNAME, PASSWORD and DOMAIN is missing or not set properly! Exiting ..."
  exit 1
fi

# -- Runtime --
source ${WORKING_DIR}/_auth_credentials.inc
HOSTNAME_SUFFIX=""
if [ "${CERTBOT_DOMAIN}" != "${DOMAIN}" ]; then
  HOSTNAME_SUFFIX=".$(echo "${CERTBOT_DOMAIN}" | sed -e s"|.${DOMAIN}$||")"
fi

echo "==============================================="

cat <<_EOF_

Setting up Let's Encrypt ACME verification for:
 - domain:    ${CERTBOT_DOMAIN}
 - challenge: ${CERTBOT_VALIDATION}
----

_EOF_

ApiLogin "${COOKIEFILE}"
sleep 0.5

FetchDomainId "DOM_ID" "${COOKIEFILE}" "${DOMAIN}"
echo "  DONE - domain ID for '${DOMAIN}': '${DOM_ID}'"
sleep 0.5

#NUM_DOMAINS=$(echo "${CERTBOT_ALL_DOMAINS}" | tr , "\n" | wc -l | tr -d " ")
#if [ "${NUM_DOMAINS}" -gt 1 ]; then
#  echo "Skip deleting old record - number of domains is greater than 1 (${NUM_DOMAINS}) ..."
#else
#  RECORD_ID="0"
#  while [ ! -z "${RECORD_ID}" ]; do
#    break
#    FindTxtRecordId "RECORD_ID" "${COOKIEFILE}" "${DOM_ID}" "${ACME_NAME_PREFIX}${HOSTNAME_SUFFIX}"
#    echo "  DONE - record ID for '${ACME_NAME_PREFIX}${HOSTNAME_SUFFIX}': '${RECORD_ID}'"
#    sleep 0.5
#  done
#fi

case "${OP}" in
auth)
  CreateTxtRecord "${COOKIEFILE}" "${DOM_ID}" "${RECORD_ID}" "${ACME_NAME_PREFIX}${HOSTNAME_SUFFIX}" "${CERTBOT_VALIDATION}"
#  if [ "${CERTBOT_REMAINING_CHALLENGES}" -eq 0 ]; then
    sleep 15
#  fi
  ;;
cleanup)
  DeleteTxtRecord "${COOKIEFILE}" "${DOM_ID}" "${RECORD_ID}"
  ;;
*)
  echo "ERROR: Unsupported operation! Exiting ..."
  exit 1
  ;;
esac
echo "==============================================="

rm -f "${COOKIEFILE}"
