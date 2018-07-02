#!/bin/bash
set -xe

cd "${HOME}"/beaker-in-a-box && ansible-playbook test.yml "${ANSIBLE_PLAYBOOK_PARAMS}"
