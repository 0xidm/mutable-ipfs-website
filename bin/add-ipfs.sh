#!/bin/bash

function process_cmdline() {
  # this sets IPFS_KEY and FILENAME globally
  while getopts 'nk:f:d:' flag; do
    case "${flag}" in
      n) NO_PUBLISH="1" ;;
      d) MFS_SUBDIR="${OPTARG}" ;;
      k) IPFS_KEY="${OPTARG}" ;;
      f) FILENAME="${OPTARG}" ;;
      *) exit 1 ;;
    esac
  done
  shift "$((OPTIND -1))"

  if [ -z "$IPFS_API" ]; then
    echo "IPFS_API environment variable not set"
    echo "Example: IPFS_API=/ip4/127.0.0.1/tcp/5001"
    exit 1
  fi

  if [ -z "$IPFS_KEY" ]; then
    echo "no key provided"
    usage
    exit 1
  fi

  if [ -z "$FILENAME" ]; then
    echo "no filename provided; will ipns publish"
    ipns_publish "$IPFS_API" "$IPFS_KEY" "$NO_PUBLISH"
    exit 0
  fi

  if [ ! -f "$FILENAME" ]; then
    echo "file not found: $FILENAME"
    exit 1
  fi

  if [ -z "$(ipfs --api=$IPFS_API key list | grep ${IPFS_KEY})" ]; then
    echo "key not found: $IPFS_KEY"
    exit 1
  fi
}

function get_cid() {
  local IPFS_API; IPFS_API=$1
  local FILENAME; FILENAME=$2

  echo -n $(ipfs --api="$IPFS_API" add -qr --offline --only-hash --cid-version=1 "$FILENAME")
}

function get_ipfs_cid() {
  local IPFS_API; IPFS_API=$1
  local FILENAME; FILENAME=$2

  echo -n /ipfs/$(get_cid "$IPFS_API" "$FILENAME")
}

function get_key_hash() {
  local IPFS_API; IPFS_API=$1
  local IPFS_KEY; IPFS_KEY=$2

  echo -n $(ipfs --api="$IPFS_API" key list -l | grep "$IPFS_KEY" | awk '{print $1}')
}

function get_ipns_path() {
  local IPFS_API; IPFS_API=$1
  local IPFS_KEY; IPFS_KEY=$2

  echo -n /ipns/$(get_key_hash "$IPFS_API" "$IPFS_KEY")
}

function get_mfs_path_cid() {
  local IPFS_API; IPFS_API=$1
  local MFS_PATH; MFS_PATH=$2

  echo -n $(ipfs --api="$IPFS_API" files stat --hash "$MFS_PATH" 2>/dev/null)
}

function check_exists() {
  local IPFS_API; IPFS_API=$1
  local IPFS_KEY; IPFS_KEY=$2
  local FILENAME; FILENAME=$3
  local MFS_DEST; MFS_DEST=$4

  local IPFS_CID; IPFS_CID=$(get_ipfs_cid "$IPFS_API" "$FILENAME")
  local REMOTE_LS; REMOTE_LS=$(ipfs --api="$IPFS_API" --timeout=1s ls "$IPFS_CID" 2>/dev/null && echo "1")

  # if REMOTE_LS is not empty, the file is already in IPFS
  if [ -n "$REMOTE_LS" ]; then
    local MFS_HASH; MFS_HASH=$(ipfs --api="$IPFS_API" files stat --hash "$MFS_DEST" 2>/dev/null)
    if [ -z "$MFS_HASH" ]; then
      echo "Create MFS link to $MFS_DEST"
      ipfs --api="$IPFS_API" files cp "$IPFS_CID" "${MFS_DEST}"
    fi

    if [ -n "$MFS_SUBDIR" ]; then
      echo $(get_ipns_path "$IPFS_API" "$IPFS_KEY")/$MFS_SUBDIR/$(basename "$FILENAME")
    else
      echo $(get_ipns_path "$IPFS_API" "$IPFS_KEY")/$(basename "$FILENAME")
    fi

    exit 0
  else
    local IPNS_PATH
    IPNS_PATH=$(get_ipns_path "$IPFS_API" "$IPFS_KEY")

    if [ -n "$MFS_SUBDIR" ]; then
      echo "Will copy $FILENAME to $IPNS_PATH/$MFS_SUBDIR"
    else
      echo "Will copy $FILENAME to $IPNS_PATH"
    fi
  fi
}

function ipfs_add() {
  local IPFS_API; IPFS_API=$1
  local FILENAME; FILENAME=$2

  echo -n "IPFS add: "
  echo /ipfs/$(ipfs --api="$IPFS_API" add -q --cid-version=1 "$FILENAME")

  echo -n "IPFS pin: "
  ipfs --api="$IPFS_API" pin add $(get_cid "$IPFS_API" "$FILENAME") 1>/dev/null
  echo OK
}

function mfs_ensure_path() {
  local IPFS_API; IPFS_API=$1
  local MFS_PATH; MFS_PATH=$2

  # if MFS path does not exist, create it
  local MFS_PATH_HASH
  MFS_PATH_HASH=$(ipfs --api="$IPFS_API" files stat --hash "$MFS_PATH" 2>/dev/null)
  if [ -n "$MFS_PATH_HASH" ]; then
    echo "MFS: path exists: $MFS_PATH"
  else
    echo -n "MFS: create path $MFS_PATH: "
    ipfs --api="$IPFS_API" files mkdir "$MFS_PATH"
    echo OK
  fi
}

function mfs_remove_link() {
  local IPFS_API; IPFS_API=$1
  local MFS_DEST; MFS_DEST=$2

  # if MFS file link already exists, delete it
  MFS_SIZE=$(ipfs --api="$IPFS_API" files stat --size "$MFS_DEST" 2>/dev/null)
  if [ -n "$MFS_SIZE" ]; then
    echo -n "MFS: remove existing link $MFS_DEST: "
    ipfs --api="$IPFS_API" files rm "$MFS_DEST"
    echo OK
  else
    echo "MFS: ready to copy"
  fi
}

function mfs_copy_cid() {
  local IPFS_API; IPFS_API=$1
  local IPFS_CID; IPFS_CID=$2
  local MFS_DEST; MFS_DEST=$3

  echo -n "MFS: copy CID to $MFS_DEST: "
  ipfs --api="$IPFS_API" files cp "/ipfs/$IPFS_CID" "$MFS_DEST"
  echo OK
}

function ipns_publish() {
  local IPFS_API; IPFS_API=$1
  local IPFS_KEY; IPFS_KEY=$2
  local NO_PUBLISH; NO_PUBLISH=$3

  if [ "$NO_PUBLISH" == "1" ]; then
    echo "IPNS: publish skipped"
    exit 0
  else
    echo -n "IPNS: publish /ipns/"
    local MFS_PATH_CID
    MFS_PATH_CID=$(get_mfs_path_cid "$IPFS_API" "/public/$IPFS_KEY")
    echo $(ipfs --api="$IPFS_API" name publish --quieter --key="$IPFS_KEY" "$MFS_PATH_CID")
  fi
}

function usage() {
  echo "Usage: $0 -k <ipfs_key> [-f <filename>] [-n]"
  echo "  -f: file to add"
  echo "  -d: destination directory in MFS"
  echo "  -k: ipfs key"
  echo "  -n: no publish"
  exit 1
}

function main() {
  local IPFS_API; IPFS_API=$1

  if [ -n "$MFS_SUBDIR" ]; then
    local MFS_DEST; MFS_DEST=/public/$IPFS_KEY/$MFS_SUBDIR/$(basename "$FILENAME")
  else
    local MFS_DEST; MFS_DEST=/public/$IPFS_KEY/$(basename "$FILENAME")
  fi

  check_exists "$IPFS_API" "$IPFS_KEY" "$FILENAME" "$MFS_DEST"

  ipfs_add "$IPFS_API" "$FILENAME"

  mfs_ensure_path "$IPFS_API" "/public/$IPFS_KEY"

  if [ -n "$MFS_SUBDIR" ]; then
    mfs_ensure_path "$IPFS_API" "/public/$IPFS_KEY/$MFS_SUBDIR"
  fi

  mfs_remove_link "$IPFS_API" "$MFS_DEST"

  mfs_copy_cid "$IPFS_API" $(get_cid "$IPFS_API" "$FILENAME") "$MFS_DEST"

  ipns_publish "$IPFS_API" "$IPFS_KEY" "$NO_PUBLISH"

  if [ -n "$MFS_SUBDIR" ]; then
    echo $(get_ipns_path "$IPFS_API" "$IPFS_KEY")/$MFS_SUBDIR/$(basename "$FILENAME")
  else
    echo $(get_ipns_path "$IPFS_API" "$IPFS_KEY")/$(basename "$FILENAME")
  fi
}

process_cmdline "$@"
main "$IPFS_API"
