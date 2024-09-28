#!/bin/bash

##
# wpatch.sh
#
# Version: 0.1.0
# Date: 2024-09-28
# Project URI: https://github.com/headwalluk/wpatcher
# Author: Paul Faulkner
# Author URI: https://headwall-hosting.com/
#
# Description
# A tool for patching and unpatching WordPress plugins and themes.
#
# IMPORTANT: This should only be used for making light changes to improve site
# performance or maintian security in abandoned plugins. It should not be used
# tp remove nullify plugins or themes. Example use cases are to remove
# excessive outgoing API calls, or to improve transient caching of slow result
# sets.
#
# See README.md for usage and examples.
# See LICENSE for licensing information.
#
IS_VERBOSE=0
IS_RUNNING_FROM_REPOS=0
STARTUP_DIR=$(realpath "$(dirname "${0}")")

REQUIRED_VARIABLE_NAMES=(
  'STARTUP_DIR'
  'WORK_DIR'
  'PATCHES_DIR'
  'WP_ROOT'
  'REQUESTED_PATCH_TYPE'
  'REPOSITORY_DIR'
  'TEMP_DIR'
  'PATCHED_DIR'
  'COMMAND'
)

REQUIRED_BINARIES=('patch' 'tar' 'wp' 'tput')

PATCH_TYPES=('plugins' 'themes')

VALID_COMMANDS=('patch' 'unpatch')

# .	Colour
# 0	Black
# 1	Red
# 2	Green
# 3	Yellow
# 4	Blue
# 5	Magenta
# 6	Cyan
# 7	White
# 8	Not used
# 9	Reset to default color
COLOUR_ERROR=1
COLOUR_GOOD=2

##
# Show usage
#
function show_usage_then_exit() {
  # Usage: tar [OPTION...] [FILE]...
  echo "Usage: $(basename "${0}") [-p <45|90>] [-p <string>] COMMAND" >&2
  exit 1
}

function show_inline_good() {
  local MESSAGE="${1}"
  echo -ne "$(tput setaf ${COLOUR_GOOD})${MESSAGE}$(tput sgr0)"
}

function show_inline_error() {
  local MESSAGE="${1}"
  echo -ne "$(tput setaf ${COLOUR_ERROR})${MESSAGE}$(tput sgr0)" >&2
}

##
# Configure and create directories
#
function configure_and_create_directories() {
  # Are we running from repository, or from installed location?
  if [ -d "${STARTUP_DIR}"/wpatches ]; then
    echo "Running from repository"
    PATCHES_DIR="${STARTUP_DIR}"/wpatches
    IS_RUNNING_FROM_REPOS=1
  fi

  if [ -n "${HOME}" ]; then
    WORK_DIR="${HOME}"/.wpatcher
  fi

  if [ -n "${WORK_DIR}" ]; then
    TEMP_DIR="${WORK_DIR}"/temp
    rm -fr "${TEMP_DIR}"
    mkdir -p "${TEMP_DIR}"

    REPOSITORY_DIR="${WORK_DIR}"/repos
    for PATCH_TYPE_DIR in "${PATCH_TYPES[@]}"; do
      mkdir -p "${REPOSITORY_DIR}"/"${PATCH_TYPE_DIR}"
    done

    PATCHED_DIR="${WORK_DIR}"/patched
    for PATCH_TYPE_DIR in "${PATCH_TYPES[@]}"; do
      mkdir -p "${PATCHED_DIR}"/"${PATCH_TYPE_DIR}"
    done
  fi
}

##
# Check all required binaries are available
#
function fail_if_missing_required_binaries() {
  for REQUIRED_BINARY in "${REQUIRED_BINARIES[@]}"; do
    if ! command -v "${REQUIRED_BINARY}" &> /dev/null; then
      echo "Missing required binary: ${REQUIRED_BINARY}"
      exit 1
    fi
  done
}

##
# Check all required (global) variables have been set
#
function fail_if_missing_required_variables() {
  for REQUIRED_VARIABLE_NAME in "${REQUIRED_VARIABLE_NAMES[@]}"; do
    REQUIRED_VARIABLE_VALUE=${!REQUIRED_VARIABLE_NAME}
    if [ -z "${REQUIRED_VARIABLE_VALUE}" ]; then
      echo "Missing required variable: ${REQUIRED_VARIABLE_NAME}"
      show_usage_then_exit
    fi
  done
}

##
# Dump all required variables
#
function dump_required_variables() {
  for REQUIRED_VARIABLE_NAME in "${REQUIRED_VARIABLE_NAMES[@]}"; do
    REQUIRED_VARIABLE_VALUE=${!REQUIRED_VARIABLE_NAME}
    echo "${REQUIRED_VARIABLE_NAME}: ${REQUIRED_VARIABLE_VALUE}"
  done
}

##
# Check a directory contains a valid WordPress installation.
# Fail if not.
#
function fail_if_bad_wp_root() {
  local WP_ROOT="${1}"
  if [ ! -f "${WP_ROOT}/wp-config.php" ]; then
    echo "Invalid WP_ROOT: ${WP_ROOT}"
    show_usage_then_exit
  fi

  wp --path="${WP_ROOT}" plugin list > /dev/null 2> /dev/null
  if [ $? -ne 0 ]; then
    echo "WordPress installation is not valid: ${WP_ROOT}"
    exit 1
  fi
}

##
# Get the site URL, and fail if it comes back empty.
#
function get_wp_site_url_but_fail_if_bad() {
  local WP_ROOT="${1}"
  local WP_URL=$(wp --path="${WP_ROOT}" --skip-plugins --skip-themes --skip-packages option get siteurl)

  if [ $? -ne 0 ] || [ -z "${WP_URL}" ]; then
    echo "Failed to get the WordPress website URL"
    exit 1
  fi

  __="${WP_URL}"
}

##
# Fail if a component has already been patched.
#
function fail_if_component_is_already_patched() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"

  has_component_been_patched "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}"
  if [ ${__} -eq 1 ]; then
    echo "Component already patched: ${COMPONENT_TYPE}/${COMPONENT_SLUG}"
    exit 1
  fi
}

##
# Fail if a component does not exist in the repository.
#
function fail_if_component_is_not_in_repository() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"
  local COMPONENT_VERSION="${4}"

  does_component_exist_in_repository "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  if [ ${__} -ne 1 ]; then
    echo "Component not in repository: ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION})"
    exit 1
  fi
}

##
# Has a omponent already been patched?
#
function has_component_been_patched() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"

  pushd "${WP_ROOT}"/wp-content/${COMPONENT_TYPE} > /dev/null
  local FILE_NAMES=($(grep -lE '^// START : wpatcher$' "${COMPONENT_SLUG}"/* 2> /dev/null))
  popd > /dev/null

  __=0
  if [ "${#FILE_NAMES[@]}" -gt 0 ]; then
    __=1
  fi
}

##
# Have we already created a tgz of the original component
# in our local repository?
#
function does_component_exist_in_repository() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"
  local COMPONENT_VERSION="${4}"

  local FILE_NAME="${REPOSITORY_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz
  __=0
  if [ -f "${FILE_NAME}" ]; then
    __=1
  fi
}

##
# Copy a component from the WP installation to our local repository.
#
function copy_component_to_repository() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"
  local COMPONENT_VERSION="${4}"

  echo -n "Save ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION}) to local repos ... "

  tar -C "${WP_ROOT}"/wp-content/${COMPONENT_TYPE} \
    -czf "${REPOSITORY_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz "${COMPONENT_SLUG}"

  if [ $? -eq 0 ]; then
    echo $(show_inline_good "OK")
    __=1
  else
    echo $(show_inline_error "failed")
    __=0
  fi
}

##
# Create a local copy of the component, apply the patch and then
# create a tgz of the patched component.
#
function create_patched_component() {
  local COMPONENT_TYPE="${1}"
  local COMPONENT_SLUG="${2}"
  local COMPONENT_VERSION="${3}"
  local IS_PATCHED=0
  local IS_PACKAGED=0

  pushd "${TEMP_DIR}" > /dev/null

  echo -n "Extract and patch ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION}) ... "
  tar -xzf "${REPOSITORY_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz
  pushd "${COMPONENT_SLUG}" > /dev/null
  patch -p1 -i "${PATCHES_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG}/${COMPONENT_SLUG}-${COMPONENT_VERSION}.patch > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    IS_PATCHED=1
    echo $(show_inline_good "OK")
  else
    echo $(show_inline_error "failed")
  fi
  popd > /dev/null

  if [ ${IS_PATCHED} -eq 1 ]; then
    echo -n "Create patched package ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION}) ... "
    tar -czf "${PATCHED_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz "${COMPONENT_SLUG}"
    if [ $? -eq 0 ]; then
      IS_PACKAGED=1
      echo $(show_inline_good "OK")
    else
      echo $(show_inline_error "failed")
    fi
  fi
  popd > /dev/null

  __=${IS_PACKAGED}
}

##
# Do we already have a tgz of the patched component & version?
#
function does_patched_component_exist() {
  local COMPONENT_TYPE="${1}"
  local COMPONENT_SLUG="${2}"
  local COMPONENT_VERSION="${3}"

  local FILE_NAME="${PATCHED_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz
  __=0
  if [ -f "${FILE_NAME}" ]; then
    __=1
  fi
}

##
# Deploy a patched component to the WP installation.
#
function deploy_patched_component() {
  local WP_ROOT="${1}"
  local COMPONENT_TYPE="${2}"
  local COMPONENT_SLUG="${3}"
  local COMPONENT_VERSION="${4}"

  local IS_OLD_COMPONENT_DELETED=0
  local IS_NEW_COMPONENT_INSTALLED=0

  pushd "${WP_ROOT}"/wp-content/${COMPONENT_TYPE} > /dev/null
  echo -n "Remove ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION}) ... "
  rm -fr "${COMPONENT_SLUG}"
  if [ $? -eq 0 ]; then
    IS_OLD_COMPONENT_DELETED=1
    echo $(show_inline_good "OK")
  else
    echo $(show_inline_error "failed")
  fi

  if [ ${IS_OLD_COMPONENT_DELETED} -eq 1 ]; then
    echo -n "Extract patched ${COMPONENT_TYPE}/${COMPONENT_SLUG} (${COMPONENT_VERSION}) ... "
    tar -xf "${PATCHED_DIR}"/${COMPONENT_TYPE}/${COMPONENT_SLUG},${COMPONENT_VERSION}.tgz
    if [ $? -eq 0 ]; then
      IS_NEW_COMPONENT_INSTALLED=1
      echo $(show_inline_good "OK")
    else
      echo $(show_inline_error "failed")
    fi
  fi

  if [ ${IS_OLD_COMPONENT_DELETED} -eq 1 ] && [ ${IS_NEW_COMPONENT_INSTALLED} -ne 1 ]; then
    echo "Failed to extract patched component: ${COMPONENT_TYPE}/${COMPONENT_SLUG}"
    echo "Attempting to reinstall the original component"
    echo "TODO..."
  fi

  popd > /dev/null

  __=0
  if [ ${IS_OLD_COMPONENT_DELETED} -eq 1 ] && [ ${IS_NEW_COMPONENT_INSTALLED} -eq 1 ]; then
    __=1
  fi
}

function apply_patch() {
  local WP_ROOT="${1}"
  local PATCH_META="${2}"

  COMPONENT_TYPE=$(echo "${PATCH_META}" | cut -d',' -f1)
  COMPONENT_SLUG=$(echo "${PATCH_META}" | cut -d',' -f2)
  COMPONENT_VERSION=$(echo "${PATCH_META}" | cut -d',' -f3)
  PATCH_FILE_NAME=$(echo "${PATCH_META}" | cut -d',' -f4)

  fail_if_component_is_already_patched "${WP_ROOT}" "${COMPONENT_TYPE}" "${PLUGIN_SLUG}"

  does_component_exist_in_repository "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  if [ ${__} -ne 1 ]; then
    copy_component_to_repository "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  fi

  fail_if_component_is_not_in_repository "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"

  does_patched_component_exist "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  if [ ${__} -ne 1 ]; then
    create_patched_component "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  fi

  does_patched_component_exist "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  if [ ${__} -eq 1 ]; then
    deploy_patched_component "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}" "${COMPONENT_VERSION}"
  fi

  # This sets __ to 1 if the component was successfully patched.
  has_component_been_patched "${WP_ROOT}" "${COMPONENT_TYPE}" "${COMPONENT_SLUG}"
}

##
# Parse command-line arguments
#
function parse_command_line() {
  while true; do
    case "${1}" in
      -p | --path)
        WP_ROOT="${2}"
        shift 2
        ;;

      -t | --type)
        REQUESTED_PATCH_TYPE="${2}"
        shift 2
        ;;

      -c | --component)
        REQUESTED_COMPONENT_SLUG="${2}"
        shift 2
        ;;

      -v | --verbose)
        IS_VERBOSE=1
        shift
        ;;

      --)
        shift
        break
        ;;

      *)
        break
        ;;

    esac
  done

  if [ -z "${WP_ROOT}" ]; then
    WP_ROOT="$(realpath "${PWD}")"
  fi

  if [ -z "${REQUESTED_PATCH_TYPE}" ]; then
    REQUESTED_PATCH_TYPE="${PATCH_TYPES[0]}"
  fi

  COMMAND="${1}"

  if [ -z "${COMMAND}" ]; then
    echo "COMMAND not specified" >&2
    show_usage_then_exit
  elif [[ ! " ${VALID_COMMANDS[*]} " =~ [[:space:]]"${COMMAND}"[[:space:]] ]]; then
    echo "COMMAND invalid: ${COMMAND}" >&2
    show_usage_then_exit
  else
    :
  fi
}

# if [ -z "${COMMAND}" ]; then
#   COMMAND='patch'
# fi

parse_command_line "${@}"

fail_if_missing_required_binaries

configure_and_create_directories

fail_if_missing_required_variables

if [ ${IS_VERBOSE} -ne 0 ]; then
  dump_required_variables
fi

fail_if_bad_wp_root "${WP_ROOT}"

get_wp_site_url_but_fail_if_bad "${WP_ROOT}"
WP_URL="${__}"

echo "Site: ${WP_URL}"

##
# Get a list of active plugins & themes on the site.
#
ACTIVE_PLUGINS=($(wp plugin list --path="${WP_ROOT}" --skip-plugins --skip-themes --skip-packages --status=active --skip-update-check --format=csv --fields=name,version | grep -vE '^name,'))
ACTIVE_THEMES=($(wp theme list --path="${WP_ROOT}" --skip-plugins --skip-themes --skip-packages --status=active,parent --skip-update-check --format=csv --fields=name,version | grep -vE '^name,'))

##
# Create a list of plugins/themes that have patches available and create a patch-list.
# Each record in the patch-list is a comma-separated string:
#
#   COMPONENT_TYPE,COMPONENT_SLUG,COMPONENT_VERSION,PATCH_FILE_NAME
#
echo "Scanning site for components to ${COMMAND}"
PATCH_LIST=()
for ACTIVE_PLUGIN_META in "${ACTIVE_PLUGINS[@]}"; do
  PLUGIN_SLUG=$(echo "${ACTIVE_PLUGIN_META}" | cut -d',' -f1)
  PLUGIN_VERSION=$(echo "${ACTIVE_PLUGIN_META}" | cut -d',' -f2)
  PATCH_FILE_NAME="${PATCHES_DIR}"/plugins/"${PLUGIN_SLUG}"/"${PLUGIN_SLUG}"-"${PLUGIN_VERSION}".patch
  IS_WANTED=0

  if [ "${REQUESTED_PATCH_TYPE}" != "plugins" ]; then
    :
  elif [ -n "${REQUESTED_COMPONENT_SLUG}" ] && [ "${REQUESTED_COMPONENT_SLUG}" != "${PLUGIN_SLUG}" ]; then
    :
  else
    [ ${IS_VERBOSE} -ne 0 ] && echo -n "PATCH: ${PATCH_FILE_NAME} ... "
    if [ -f "${PATCH_FILE_NAME}" ]; then
      has_component_been_patched "${WP_ROOT}" plugins "${PLUGIN_SLUG}"
      HAS_BEEN_PATCHED=${__}

      if [ "${COMMAND}" == 'unpatch' ] && [ ${HAS_BEEN_PATCHED} -eq 1 ]; then
        IS_WANTED=1
      elif [ "${COMMAND}" == 'patch' ] && [ ${HAS_BEEN_PATCHED} -eq 0 ]; then
        IS_WANTED=1
      else
        :
      fi

      if [ ${IS_WANTED} -eq 1 ]; then
        [ ${IS_VERBOSE} -ne 0 ] && echo "${COMMAND}"
        PATCH_LIST+=("plugins,${PLUGIN_SLUG},${PLUGIN_VERSION},${PATCH_FILE_NAME}")
      else
        [ ${IS_VERBOSE} -ne 0 ] && echo "skip"
      fi
    else
      [ ${IS_VERBOSE} -ne 0 ] && echo "n/a"
    fi
  fi
done

if [ "${#PATCH_LIST[@]}" -eq 0 ]; then
  echo "There are no components to ${COMMAND}"
  exit 0
fi

echo "${COMMAND} list"
printf ' >>> %s\n' "${PATCH_LIST[@]}"

##
# Ready to apply the patch list.
#
for PATCH_META in "${PATCH_LIST[@]}"; do
  if [ "${COMMAND}" == 'patch' ]; then
    apply_patch "${WP_ROOT}" "${PATCH_META}"
  elif [ "${COMMAND}" == 'unpatch' ]; then
    echo "UNPATCH IN HERE"
  else
    # Unknown command
    :
  fi
done

echo "Finished"
exit 0
