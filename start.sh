#!/bin/bash

exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  if [ "$rc" = 0 ]; then
    return
  fi
  if [ "$CLEAN_GIT_LOCK_FILES" = "true" ] && [ "$IS_RETRY" != "true" ]; then
    retry_script
    exit $?
  fi
  echo "Command [$lc] exited with code [$rc]"
}

retry_script () {
  echo "Retrying git clone operation..."
  cd ../
  rm -rf $CLONE_DIR
  export IS_RETRY=true
  $0 $@
}

git_retry () {
# Retry git on exit code 128
(
   set +e
   RETRY_ON_SIGNAL=128
   COMMAND=("$@")  # Store the command and arguments as an array
   local TRY_NUM=1 MAX_TRIES=4 RETRY_WAIT=5
   until [[ "$TRY_NUM" -ge "$MAX_TRIES" ]]; do
      "${COMMAND[@]}"  # Use "${COMMAND[@]}" to preserve arguments with quotes
      EXIT_CODE=$?
      if [[ $EXIT_CODE == 0 ]]; then
        break
      elif [[ $EXIT_CODE == "$RETRY_ON_SIGNAL" ]]; then
        echo "Failed with Exit Code $EXIT_CODE - try $TRY_NUM "
        TRY_NUM=$(( ${TRY_NUM} + 1 ))
        sleep $RETRY_WAIT
      else
        break
      fi
   done
   return $EXIT_CODE
   )
}

upsert_remote_alias () {
  remoteAlias=$1
  remoteUrl=$2
  isOriginAliasExisted=$(git remote -v | awk '$1 ~ /^'$remoteAlias'$/{print $1; exit}')
  if [ "$isOriginAliasExisted" = "$remoteAlias" ]; then
    git remote set-url $remoteAlias $remoteUrl
  else
    git remote add $remoteAlias $remoteUrl
  fi
}

delete_process_lock_files () {
  ARE_PROCEE_LOCK_FILES=$(find ./.git -type f -iname '*.lock')
  if [ -n "$ARE_PROCEE_LOCK_FILES" ]; then
    echo Deleting process lock files:
    echo $ARE_PROCEE_LOCK_FILES
    find ./.git -type f -iname '*.lock' -delete
  fi
}

git_checkout () {
  revision="$REVISION"
  # when revision is Gerrit branch we need to fetch it explicitly
  if [[ "$REVISION" =~ ^refs/changes/[0-9]+/[0-9]+/[0-9]+$ ]]; then
    echo "Fetching Gerrit Change ref: $REVISION"
    git_retry git fetch origin $REVISION
    revision="FETCH_HEAD"
  fi

  git checkout $revision
}

trap exit_trap EXIT
set -e

[ -z "$REVISION" ] && (echo "missing REVISION var" | tee /dev/stderr) && exit 1


if [ "$USE_SSH" = "true" ]; then
    echo "Cloning using SSH: $REPO"

    [ -z "$PRIVATE_KEY" ] && (echo "missing PRIVATE_KEY var" | tee /dev/stderr) && exit 1

    echo "$PRIVATE_KEY" > /root/.ssh/codefresh
    chmod 700 ~/.ssh/
    chmod 600 ~/.ssh/*

    # ssh://git@github.com:username/repo.git
    # match "github.com" from ssh uri
    REPO=${REPO#"ssh://"}


    # was: git@host:1234:username/repo.git
    # or: git@host:1234/repo.git
    # or: git@host:username/repo.git
    # became: `1234` (will be accepted by check)
    # or: `username` (will be skipped by check)
    SSH_PORT=$(echo "$REPO" | cut -d ":" -f 2 | cut -d "/" -f 1)

    # we need to add port to ssh host in the known_hosts file
    # otherwise it will ask to add host to known_hosts
    # during git clone
    SSH_PORT_PARAM=''
    SSH_PORT_LOG=''
    if [[ "$SSH_PORT" =~ ^[0-9]{1,5}$ ]]; then
        SSH_PORT_PARAM="-p $SSH_PORT"
        SSH_PORT_LOG=":$SSH_PORT"
    fi

    # was: git@github.com:username/repo.git
    # became: github.com
    SSH_HOST=$(echo "$REPO" | cut -d ":" -f 1 | cut -d "@" -f 2)

    echo "Adding "$SSH_HOST$SSH_PORT_LOG" to known_hosts"

    # removes all keys belonging to hostname from a known_hosts file
    ssh-keygen -R $SSH_HOST 2>/dev/null
    # skip stderr logs that start with '#'
    ssh-keyscan "$SSH_PORT_PARAM" -H $SSH_HOST > ~/.ssh/known_hosts 2> >(grep -v '^#' >&2)
fi

mkdir -p "$WORKING_DIRECTORY"
cd $WORKING_DIRECTORY

git config --global advice.detachedhead false
git config --global credential.helper "/bin/sh -c 'echo username=$USERNAME; echo password=$PASSWORD'"

set +e
git config --global --unset http.proxy
set -e
if [ -n "$HTTP_PROXY" ]; then
    echo "Using HTTP_PROXY"
    git config --global http.proxy "$HTTP_PROXY"
else
    if [ -n "$HTTPS_PROXY" ]; then
        echo "Using HTTPS_PROXY"
        git config --global http.proxy "$HTTPS_PROXY"
    fi
fi


if [ -n "$SPARE_CHECKOUT" ]; then
    echo "spare checkout"
    if [ -d "$CLONE_DIR" ]; then
      echo "folder exists - no need to init"
      cd $CLONE_DIR
    else
      git init $CLONE_DIR
      chmod -R 774 $CLONE_DIR
      cd $CLONE_DIR
      git remote add origin $REPO
      git config core.sparsecheckout true
      echo "$SOURCE/*" >> .git/info/sparse-checkout
    fi

    git pull --depth=1 origin $REVISION
    exit 0
 fi

if [ -n "$DEPTH" ]; then
  GIT_COMMAND="git_retry git clone $REPO $CLONE_DIR --depth=$DEPTH"
else
  GIT_COMMAND="git_retry git clone $REPO $CLONE_DIR"
fi

# Check if the cloned dir already exists from previous builds
if [ -d "$CLONE_DIR" ]; then

  # Cloned dir already exists from previous builds so just fetch all the changes
  echo "Preparing to update repository $REPO_RAW"
  cd $CLONE_DIR

  # Make sure the CLONE_DIR folder is a git folder
  if git status &> /dev/null ; then
      if [ "$CLEAN_GIT_LOCK_FILES" = "true" ]; then
        delete_process_lock_files
      fi
      # Reset the remote URL because the embedded user token may have changed
      upsert_remote_alias origin $REPO

      echo "Cleaning up the working directory"
      git reset -q --hard
      git clean -df
      git gc --force
      git_retry git remote prune origin
      git_retry git fetch origin --tags --prune "+refs/tags/*:refs/tags/*"

      echo "Fetching the updates from origin"
      git_retry git fetch --tags
      git remote set-head origin --auto

      if [ -n "$REVISION" ]; then

          echo "Updating repository to revision $REVISION"
          git_checkout

          CURRENT_BRANCH="`git branch 2>/dev/null | grep '^*' | cut -d' ' -f2-`"

          # If the revision is identical to the current branch we can just reset it to the latest changes. This isn't needed when running detached
          if [ "$REVISION" == "$CURRENT_BRANCH" ]; then
             echo 'Resetting current branch $REVISION to latest changes...'
             git reset --hard origin/$REVISION
          fi
      fi
  else
      # The folder already exists but it is not a git repository
      # Clean folder and clone a fresh copy on current directory
      cd ..
      rm -rf $CLONE_DIR
      eval $GIT_COMMAND
      cd $CLONE_DIR

      if [ -n "$REVISION" ]; then
          if [ -n "$DEPTH" ]; then
            git_retry git remote set-branches origin "*"
            git_retry git fetch --depth=$DEPTH
          fi
        git_checkout
      fi
  fi
else

 # Clone a fresh copy
  eval $GIT_COMMAND
  cd $CLONE_DIR
  if [ -n "$REVISION" ]; then
      if [ -n "$DEPTH" ]; then
        git_retry git remote set-branches origin "*"
        git_retry git fetch --depth=$DEPTH
      fi
    git_checkout
  fi

fi
