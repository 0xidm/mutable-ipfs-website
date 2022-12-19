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
  echo -n "IPFS: add /ipfs/"
  ipfs --api="$IPFS_API" add -q --cid-version=1 "$FILENAME"
}

function ipfs_pin_file() {
  local FILENAME; FILENAME=$1
  echo -n "IPFS: pin "
  ipfs --api="$IPFS_API" pin add $(get_ipfs_cid "$FILENAME") 1>/dev/null
  echo OK
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
  echo -n "MFS: copy $IPFS_CID to $MFS_FILENAME "
  ipfs --api="$IPFS_API" files cp "/ipfs/$IPFS_CID" "$MFS_FILENAME"
  echo OK
}

function mfs_copy_file() {
  local FILENAME; FILENAME=$1
  local MFS_FILENAME; MFS_FILENAME=$2
  mfs_copy_cid $(get_ipfs_cid "$FILENAME") "$MFS_FILENAME"
}

function mfs_mkdir() {
  local MFS_PATH; MFS_PATH=$1
  if [ -z "$(mfs_exists $MFS_PATH)" ]; then
    echo -n "MFS: create path $MFS_PATH "
    ipfs --api="$IPFS_API" files mkdir "$MFS_PATH"
    echo OK
  fi
}

function mfs_unlink() {
  local MFS_PATH; MFS_PATH=$1
  if [ ! -z $(mfs_exists $MFS_PATH) ]; then
    echo -n "MFS: remove link $MFS_PATH "
    ipfs --api="$IPFS_API" files rm "$MFS_PATH"
    echo OK
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
    echo "MFS: create link $MFS_PATH"
    ipfs --api="$IPFS_API" files cp "/ipfs/$IPFS_CID" "$MFS_PATH"
    echo OK
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
  echo -n "IPNS: publish /ipns/"
  ipfs --api="$IPFS_API" name publish --quieter --key="$IPFS_KEY" \
    $(get_mfs_hash "/public/$IPFS_KEY")
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

function process_cmdline() {
  if [ -z "$IPFS_API" ]; then
    echo "IPFS_API environment variable not set"
    echo "Example: IPFS_API=/ip4/127.0.0.1/tcp/5001"
    exit 1
  fi

  # these variables are global; only use within main()
  while getopts 'pk:f:d:' flag; do
    case "${flag}" in
      p) _PUBLISH="1" ;;
      d) _MFS_SUBDIR="${OPTARG}" ;;
      k) _IPFS_KEY="${OPTARG}" ;;
      f) _FILENAME="${OPTARG}" ;;
      *) usage; exit 1 ;;
    esac
  done
  shift "$((OPTIND -1))"

  if [ -z "$_IPFS_KEY" ]; then
    echo "no key provided"
    usage
    exit 1
  fi
}

function main() {
  if [ -z "$(key_exists $_IPFS_KEY)" ]; then
    echo "key not found: $_IPFS_KEY"
    exit 1
  fi

  if [ -f "$_FILENAME" ]; then
    local MFS_FILENAME; MFS_FILENAME=$(get_mfs_filename "$_IPFS_KEY" "$_MFS_SUBDIR" "$_FILENAME")

    if [ -z $(ipfs_file_exists "$_FILENAME") ]; then
      ipfs_add_file "$_FILENAME"
      ipfs_pin_file "$_FILENAME"
      mfs_create_path "$_IPFS_KEY" "$_MFS_SUBDIR"
      mfs_copy_file "$_FILENAME" "$MFS_FILENAME"
      if [ ! -z "$_PUBLISH" ]; then ipns_publish "$_IPFS_KEY"; fi
    else
      mfs_link_file "$_FILENAME" "$MFS_FILENAME"
    fi

    echo $(get_ipns_filename "$_IPFS_KEY" "$MFS_FILENAME")
  else
    if [ ! -z "$_PUBLISH" ]; then 
      ipns_publish "$_IPFS_KEY"
    else
      echo "file not found: $_FILENAME"
    fi    
  fi
}

process_cmdline "$@"
main
