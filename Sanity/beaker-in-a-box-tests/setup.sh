#!/bin/bash
set -xe
REFSPEC=${GERRIT_REFSPEC:-master}

cd "${HOME}"
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''

git clone http://gerrit.beaker-project.org/beaker-in-a-box
pushd beaker-in-a-box

# Avoid git error: fatal: empty ident name (for <testuser@host>) not allowed
git config user.email "testuser@localhost"
git config user.name "Beaker-in-a-box TestUser"

git pull https://gerrit.beaker-project.org/beaker-in-a-box "${REFSPEC}"
