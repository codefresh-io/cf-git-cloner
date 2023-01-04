#!/bin/bash

exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  if [ $rc != 0 ]; then
    echo "Command [$lc] exited with code [$rc]"
  fi
}

git_retry () {
# Retry git on exit code 128
(
   set +e
   RETRY_ON_SIGNAL=128
   COMMAND=$@
   local TRY_NUM=1 MAX_TRIES=4 RETRY_WAIT=5
   until [[ "$TRY_NUM" -ge "$MAX_TRIES" ]]; do
      $COMMAND
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
    SSH_HOST=$(echo "$REPO" | cut -d ":" -f 1 | cut -d "@" -f 2)

    echo "Adding "$SSH_HOST" to known_hosts"

    # removes all keys belonging to hostname from a known_hosts file
    ssh-keygen -R $SSH_HOST 2>/dev/null
    # skip stderr logs that start with '#'
    ssh-keyscan -H $SSH_HOST > ~/.ssh/known_hosts 2> >(grep -v '^#' >&2)
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
  GIT_COMMAND="git clone $REPO $CLONE_DIR --depth=$DEPTH"
else
  GIT_COMMAND="git clone $REPO $CLONE_DIR"
fi

# Check if the cloned dir already exists from previous builds
if [ -d "$CLONE_DIR" ]; then

  # Cloned dir already exists from previous builds so just fetch all the changes
  echo "Preparing to update repository $REPO_RAW"
  cd $CLONE_DIR

  # Make sure the CLONE_DIR folder is a git folder
  if git status &> /dev/null ; then
      # Reset the remote URL because the embedded user token may have changed
      git remote set-url origin $REPO

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
          git checkout $REVISION

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
      git_retry $GIT_COMMAND
      cd $CLONE_DIR

      if [ -n "$REVISION" ]; then
        git checkout $REVISION
      fi
  fi
else

 # Clone a fresh copy
  git_retry $GIT_COMMAND
  cd $CLONE_DIR
  if [ -n "$REVISION" ]; then
    git checkout $REVISION
  fi

fi
