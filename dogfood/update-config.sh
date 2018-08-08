#!/bin/sh
set -e

# Updates the Beaker config to match what the tests are expecting.

if [ -e /etc/beaker/server.cfg ] ; then
    sed --regexp-extended --in-place=-orig --copy -e '
        /^#?beaker\.log_delete_user/c       beaker.log_delete_user = "log-delete"
        /^#?beaker\.log_delete_password/c   beaker.log_delete_password = "password"
        /^#?mail\.on/c                      mail.on = True
        /^#?mail\.smtp\.server/c            mail.smtp.server = "127.0.0.1:19999"
        /^#?beaker\.reliable_distro_tag/c   beaker.reliable_distro_tag = "RELEASED"
        /^#?beaker\.motd/c                  beaker.motd = "/usr/share/beaker-integration-tests/motd.xml"
        /^#?beaker\.max_running_commands /c beaker.max_running_commands = 10
        /^#?beaker\.kernel_options /c       beaker.kernel_options = "noverifyssl"
        /^#?identity\.ldap\.enabled/c       identity.ldap.enabled = True
        /^#?identity\.soldapprovider\.uri/c identity.soldapprovider.uri = "ldap://localhost:3899/"
        /^#?identity\.soldapprovider\.basedn/c identity.soldapprovider.basedn = "dc=example,dc=invalid"
        /^#?identity\.soldapprovider\.autocreate/c identity.soldapprovider.autocreate = True
        /^#?openstack\.dashboard_url/c      openstack.dashboard_url = "http://openstack.example.invalid/dashboard/"
        /\[global\]/a                       beaker.migration_test_dburi = "mysql://beaker:beaker@localhost/beaker_migration_test?charset=utf8"
        ' /etc/beaker/server.cfg
    service httpd reload
fi

if [ -e /etc/beaker/labcontroller.conf ] ; then
    sed --regexp-extended --in-place=-orig --copy -e '
        $a SLEEP_TIME = 5
        $a POWER_ATTEMPTS = 2
        ' /etc/beaker/labcontroller.conf
    # Added in Beaker 26.0+
    watchdog_script=$(echo /usr/lib/python2.*/site-packages/bkr/inttest/labcontroller/watchdog-script-test.sh)
    if [ -e "$watchdog_script" ] ; then
        sed --regexp-extended --in-place -e "
            \$a WATCHDOG_SCRIPT = \"$watchdog_script\"
            " /etc/beaker/labcontroller.conf
    fi
    service beaker-proxy condrestart
    service beaker-provision condrestart
    service beaker-watchdog condrestart
    service beaker-transfer condrestart
fi

if [ -e /etc/cron.d/beaker ] ; then
    # Comment out beaker-refresh-ldap cron job, since it won't do anything most 
    # of the time, but it can interfere with tests which are invoking 
    # beaker-refresh-ldap directly.
    sed --in-place=-orig --copy -e '
        /beaker-refresh-ldap/ s/^/#/
        ' /etc/cron.d/beaker
fi
