#!/bin/bash

###
# IPFS

function get_ipfs_cid() {
  local FILENAME; FILENAME=$1
  ipfs --api="$IPFS_API" add -qr --offline --only-hash --cid-version=1 "$FILENAME"
}

function ipfs_cid_exists() {
  local IPFS_CID; IPFS_CID=$1
  ipfs --api="$IPFS_API" --timeout=1s ls "$IPFS_CID" 2>/dev/null && echo "1"
}

function ipfs_file_exists() {
  local FILENAME; FILENAME=$1
  ipfs_cid_exists $(get_ipfs_cid "$FILENAME")
}

function ipfs_add_file() {
  local FILENAME; FILENAME=$1
  ipfs --api="$IPFS_API" add -q --cid-version=1 "$FILENAME" 1>/dev/null
}

function ipfs_pin_file() {
  local FILENAME; FILENAME=$1
  ipfs --api="$IPFS_API" pin add $(get_ipfs_cid "$FILENAME") 1>/dev/null
}

###
# MFS

function get_mfs_filename() {
  local IPFS_KEY; IPFS_KEY=$1
  local MFS_SUBDIR; MFS_SUBDIR=$2
  local FILENAME; FILENAME=$3
  if [ -n "$MFS_SUBDIR" ]; then
    echo -n /public/$IPFS_KEY/$MFS_SUBDIR/$(basename "$FILENAME")
  else
    echo -n /public/$IPFS_KEY/$(basename "$FILENAME")
  fi
}

function get_mfs_hash() {
  local MFS_PATH; MFS_PATH=$1
  ipfs --api="$IPFS_API" files stat --hash "$MFS_PATH" 2>/dev/null
}

function mfs_exists() {
  local MFS_PATH; MFS_PATH=$1
  if [ ! -z "$(get_mfs_hash $MFS_PATH)" ]; then echo "1"; fi
}

function mfs_copy_cid() {
  local IPFS_CID; IPFS_CID=$1
  local MFS_FILENAME; MFS_FILENAME=$2
  mfs_unlink "$MFS_FILENAME"  
  ipfs --api="$IPFS_API" files cp "/ipfs/$IPFS_CID" "$MFS_FILENAME"
}

function mfs_copy_file() {
  local FILENAME; FILENAME=$1
  local MFS_FILENAME; MFS_FILENAME=$2
  mfs_copy_cid $(get_ipfs_cid "$FILENAME") "$MFS_FILENAME"
}

function mfs_mkdir() {
  local MFS_PATH; MFS_PATH=$1
  if [ -z "$(mfs_exists $MFS_PATH)" ]; then
    ipfs --api="$IPFS_API" files mkdir "$MFS_PATH"
  fi
}

function mfs_unlink() {
  local MFS_PATH; MFS_PATH=$1
  if [ ! -z $(mfs_exists $MFS_PATH) ]; then
    ipfs --api="$IPFS_API" files rm "$MFS_PATH"
  fi
}

function mfs_link_file() {
  local FILENAME; FILENAME=$1
  local MFS_FILENAME; MFS_FILENAME=$2
  mfs_link_cid $(get_ipfs_cid "$FILENAME") "$MFS_FILENAME"
}

function mfs_link_cid() {
  local IPFS_CID; IPFS_CID=$1
  local MFS_PATH; MFS_PATH=$2
  if [ -z "$(get_mfs_hash $MFS_PATH)" ]; then
    ipfs --api="$IPFS_API" files cp "/ipfs/$IPFS_CID" "$MFS_PATH"
  fi
}

function mfs_create_path() {
  local IPFS_KEY; IPFS_KEY=$1
  local MFS_SUBDIR; MFS_SUBDIR=$2
  mfs_mkdir "/public/$IPFS_KEY"
  if [ -n "$MFS_SUBDIR" ]; then 
    mfs_mkdir "/public/$IPFS_KEY/$MFS_SUBDIR"
  fi
}

###
# IPNS

function ipns_publish() {
  local IPFS_KEY; IPFS_KEY=$1
  ipfs --api="$IPFS_API" name publish --quieter --key="$IPFS_KEY" \
    $(get_mfs_hash "/public/$IPFS_KEY") 1>/dev/null
}

function get_ipns_filename() {
  local IPFS_KEY; IPFS_KEY=$1
  local MFS_FILENAME; MFS_FILENAME=$2
  echo -n /ipns/$(get_key_hash_base58 "$IPFS_KEY")/$(echo "$MFS_FILENAME" | cut -d'/' -f4-)
}

###
# Keys

function get_key_hash() {
  local IPFS_KEY; IPFS_KEY=$1
  ipfs --api="$IPFS_API" key list -l | grep "$IPFS_KEY" | awk '{print $1}'
}

function get_key_hash_base58() {
  local IPFS_KEY; IPFS_KEY=$1
  ipfs --api="$IPFS_API" key list -l --ipns-base b58mh | grep "$IPFS_KEY" | awk '{print $1}'
}

function key_exists() {
  local IPFS_KEY; IPFS_KEY=$1
  if [ ! -z $(get_key_hash $IPFS_KEY) ]; then echo "1"; fi
}

###
# Main

function usage() {
  echo "Usage: $0 -k <ipfs_key> [-d <subdir>] [-f <filename>] [-p]"
  echo "  -k: ipfs key"
  echo "  -d: subdir in MFS"
  echo "  -f: file to add"
  echo "  -p: publish to ipns"
}

function run_with_args() {
  local IPFS_KEY
  local MFS_SUBDIR
  local FILENAME
  local PUBLISH

  if [ -z "$IPFS_API" ]; then
    echo "IPFS_API environment variable not set"
    echo "Example: IPFS_API=/ip4/127.0.0.1/tcp/5001"
    exit 1
  fi

  while getopts 'pk:f:d:' flag; do
    case "${flag}" in
      p) PUBLISH="1" ;;
      d) MFS_SUBDIR="${OPTARG}" ;;
      k) IPFS_KEY="${OPTARG}" ;;
      f) FILENAME="${OPTARG}" ;;
      *) usage; exit 1 ;;
    esac
  done
  shift "$((OPTIND -1))"

  if [ -z "$IPFS_KEY" ]; then
    echo "no key provided"
    usage
    exit 1
  fi

  # all local variables are visible within main
  main
}

function main() {
  if [ -z "$(key_exists $IPFS_KEY)" ]; then
    echo "key not found: $IPFS_KEY"
    exit 1
  fi

  if [ -f "$FILENAME" ]; then
    local MFS_FILENAME; MFS_FILENAME=$(get_mfs_filename "$IPFS_KEY" "$MFS_SUBDIR" "$FILENAME")

    if [ -z $(ipfs_file_exists "$FILENAME") ]; then
      echo -n "IPFS: add $FILENAME "
      ipfs_add_file "$FILENAME"
      ipfs_pin_file "$FILENAME"
      echo OK

      echo -n "MFS: copy to $MFS_FILENAME "
      mfs_create_path "$IPFS_KEY" "$MFS_SUBDIR"
      mfs_copy_file "$FILENAME" "$MFS_FILENAME"
      echo OK

      if [ ! -z "$PUBLISH" ]; then 
        echo -n "IPNS: publish "
        ipns_publish "$IPFS_KEY"
        echo OK
      fi
    else
      mfs_link_file "$FILENAME" "$MFS_FILENAME"
    fi

    echo $(get_ipns_filename "$IPFS_KEY" "$MFS_FILENAME")
  else
    if [ ! -z "$PUBLISH" ]; then 
      echo -n "IPNS: publish "
      ipns_publish "$IPFS_KEY"
      echo OK
    else
      echo "file not found: $FILENAME"
    fi    
  fi
}

run_with_args "$@"
