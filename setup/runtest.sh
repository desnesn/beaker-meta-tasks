#!/bin/bash

# Copyright (c) 2006 Red Hat, Inc. All rights reserved. This copyrighted material 
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Bill Peck <bpeck@redhat.com>

# source the test script helpers
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh

function CheckDistro()
{
    rlIsFedora '>=18' || rlIsRHEL '>=7'
    future_distro=$?
}

CheckDistro

function generate_rsync_cfg()
{
    rlRun "mkdir -p /var/www/html/beaker-logs"
    rlRun "chown nobody /var/www/html/beaker-logs"
    rlRun "chmod 755 /var/www/html/beaker-logs"
    cat <<__EOF__ > /etc/rsyncd.conf
use chroot = false

[beaker-logs]
	path = /var/www/html/beaker-logs
	comment = beaker logs
	read only = false
__EOF__
    rlAssert0 "Wrote rsyncd.conf" $?
}

function generate_proxy_cfg()
{
    cat << __EOF__ > /etc/beaker/labcontroller.conf
HUB_URL = "http://$SERVER/bkr/"
AUTH_METHOD = "password"
USERNAME = "host/$(hostname -f)"
PASSWORD = "testing"
CACHE = True
ARCHIVE_SERVER = "http://$SERVER/beaker-logs"
ARCHIVE_BASEPATH = "/var/www/html/beaker"
ARCHIVE_RSYNC = "rsync://$SERVER/beaker-logs"
RSYNC_FLAGS = "-arv --timeout 300"
QPID_BUS=False
__EOF__
    rlAssert0 "Wrote /etc/beaker/labcontroller.conf" $?
}

function Client()
{
    rlPhaseStartTest "Configure Beaker client"
    cat <<__EOF__ >/etc/beaker/client.conf
HUB_URL = "http://$SERVER/bkr"
AUTH_METHOD = "password"
USERNAME = "admin"
PASSWORD = "testing"
__EOF__
    rlAssert0 "Wrote /etc/beaker/client.conf" $?
    rlPhaseEnd
}

function Inventory()
{
    rlPhaseStartTest "Install database"
    if rlIsFedora ; then
        rlAssertRpm mariadb-server
        rlAssertRpm mariadb
        rlAssertRpm python2-mysql
        cat >/etc/my.cnf.d/beaker.cnf <<EOF
[mysqld]
max_allowed_packet=50M
character_set_server=utf8
$MYSQL_EXTRA_CONFIG
EOF
        rlAssert0 "Wrote /etc/my.cnf.d/beaker.cnf" $?
        rlServiceStart mariadb
    elif rlIsRHEL 7 ; then
        rlAssertRpm rh-mariadb102-mariadb-server
        # This one gives us /usr/bin/mysql as a wrapper script:
        rlAssertRpm rh-mariadb102-mariadb-syspaths
        rlAssertRpm MySQL-python
        cat >/etc/opt/rh/rh-mariadb102/my.cnf.d/beaker.cnf <<EOF
[mysqld]
max_allowed_packet=50M
character_set_server=utf8
$MYSQL_EXTRA_CONFIG
EOF
        rlAssert0 "Wrote /etc/opt/rh/rh-mariadb102/my.cnf.d/beaker.cnf" $?
        rlServiceStart rh-mariadb102-mariadb
    else # RHEL6
        rlAssertRpm mysql-server
        rlAssertRpm MySQL-python
        # Backup /etc/my.cnf and update the config
        rlRun "cp /etc/my.cnf /etc/my.cnf-orig" 0
        cat /etc/my.cnf-orig | awk '
            {print $0};
            /\[mysqld\]/ {
                print "max_allowed_packet=50M";
                print "character-set-server=utf8";
                print ENVIRON["MYSQL_EXTRA_CONFIG"];
            }' > /etc/my.cnf
        rlAssert0 "Configured /etc/my.cnf" $?
        rlServiceStart mysqld
    fi
    rlRun "mysql -u root -e \"CREATE DATABASE beaker;\"" 0 "Creating database 'beaker'"
    rlRun "mysql -u root -e \"GRANT ALL ON beaker.* TO beaker@localhost IDENTIFIED BY 'beaker';\"" 0 "Granting privileges to the user 'beaker@localhost'"
    rlPhaseEnd

    rlPhaseStartTest "Install Beaker server"
    rlRun "yum install -y beaker-server$VERSION"
    rlLog "Installed $(rpm -q beaker-server)"
    if [[ -n "$EXPECT_BEAKER_GIT_BUILD" && "$(rpm -q beaker-server)" != *.git.* ]] ; then
        rlDie "Git build was not installed (hint: does destination branch contain latest tags?)"
    fi
    rlPhaseEnd

    rlPhaseStartTest "Configure Beaker server"
    rlRun "mkdir -p /var/www/beaker/harness" 0 "in lieu of running beaker-repo-update"
    cat << __EOF__ > /etc/beaker/motd.txt
<span>Integration tests are running against this server</span>
__EOF__
    rlPhaseEnd

    if [ -n "$IMPORT_DB" ] ; then
        rlPhaseStartTest "Import database dump"
        rlRun "wget $IMPORT_DB" 0 "Retrieving remote DB"
        DB_FILE=echo $IMPORT_DB | perl -pe 's|.+/(.+\.xz)$|\1|'
        rlRun "xzcat $DB_FILE | mysql" 0 "Importing DB"
        rlPhaseEnd
    else
        rlPhaseStartTest "Initialize database"
        rlRun "beaker-init -u admin -p testing -e $SUBMITTER" 0
        rlPhaseEnd
    fi

    rlPhaseStartTest "Configure firewall"
    # XXX we can do better than this
    if [[ $future_distro -eq 0 ]]; then
        rlServiceStop firewalld
    else
        rlServiceStop iptables
    fi
    rlPhaseEnd

    if [ -n "$GRAPHITE_SERVER" ] ; then
        rlPhaseStartTest "Configure Beaker for Graphite"
        sed -i \
            -e "/^#carbon.address /c carbon.address = ('$GRAPHITE_SERVER', ${GRAPHITE_PORT:-2023})" \
            -e "/^#carbon.prefix /c carbon.prefix = '${GRAPHITE_PREFIX:+$GRAPHITE_PREFIX.}beaker.'" \
            /etc/beaker/server.cfg
        rlAssert0 "Added carbon settings to /etc/beaker/server.cfg" $?
        rlPhaseEnd
    fi

    if [ -n "$OPENSTACK_IDENTITY_API_URL" ] ; then
        rlPhaseStartTest "Configure Beaker for OpenStack"
        sed -i \
            -e "/^#openstack.identity_api_url /c openstack.identity_api_url = '$OPENSTACK_IDENTITY_API_URL'" \
            -e "/^#openstack.user_domain_name /c openstack.user_domain_name = '$OPENSTACK_BEAKER_USER_DOMAIN_NAME'" \
            -e "/^#openstack.username /c openstack.username = '$OPENSTACK_BEAKER_USERNAME'" \
            -e "/^#openstack.password /c openstack.password = '$OPENSTACK_BEAKER_PASSWORD'" \
            /etc/beaker/server.cfg
        rlAssert0 "Added OpenStack settings to /etc/beaker/server.cfg" $?
        rlPhaseEnd
    fi

    if [ -n "$COLLECT_COVERAGE" ] ; then
        rlPhaseStartTest "Configure Beaker server for coverage collection"
        sed -e "$ a\coverage=True" -i /etc/beaker/server.cfg
        rlAssert0 "Collecting coverage for Beaker server" $?
        rlPhaseEnd
    fi

    # https://bugzilla.redhat.com/show_bug.cgi?id=1478149
    # gobject-introspection module loader deadlocks inside mod_wsgi.
    # Workaround is from https://bugzilla.redhat.com/show_bug.cgi?id=1475969,
    # configure python-keyring not to try importing the GNOME stuff.
    if rlIsRHEL 7 ; then
        rlPhaseStartTest "Work around bz1478149"
        rlRun "mkdir -p /usr/share/httpd/.local/share/python_keyring/"
        cat >/usr/share/httpd/.local/share/python_keyring/keyringrc.cfg <<EOF
[backend]
default-keyring=keyring.backends.file.EncryptedKeyring
EOF
        rlAssert0 "Wrote python-keyring config" $?
        rlPhaseEnd
    fi

    rlPhaseStartTest "Start services"
    rlServiceStart httpd
    rlServiceStart beakerd
    rlPhaseEnd

    rlPhaseStartTest "Add lab controllers"
    rlRun "curl -f -s -o /dev/null -c cookie -d user_name=admin -d password=testing -d login1 http://$SERVER/bkr/login" 0 "Log in to Beaker"
    for CLIENT in $CLIENTS; do
        rlRun -c "curl -f -s -o /dev/null -b cookie -d fqdn=$CLIENT -d lusername=host/$CLIENT -d lpassword=testing -d email=root@$CLIENT http://$SERVER/bkr/labcontrollers/save" 0 "Add lab controller $CLIENT"
    done
    rlPhaseEnd

    rlPhaseStartTest "Enable rsync for fake archive server"
    generate_rsync_cfg
    if [[ $future_distro -eq 0 ]]; then
        rlRun "systemctl enable rsyncd"
    else
        rlRun "chkconfig rsync on"
        rlServiceStart xinetd
    fi
    rlPhaseEnd

    if [ -n "$ENABLE_COLLECTD" ] ; then
        rlPhaseStartTest "Enable collectd for metrics collection"
        rlRun "yum install -y collectd"
        cat >/etc/collectd.d/beaker-server.conf <<EOF
LoadPlugin processes
LoadPlugin write_graphite
<Plugin write_graphite>
  <Carbon>
    Host "$GRAPHITE_SERVER"
    Port "${GRAPHITE_PORT:-2023}"
    Prefix "${GRAPHITE_PREFIX:+$GRAPHITE_PREFIX/}host/"
  </Carbon>
</Plugin>
<Plugin processes>
  Process "beakerd"
  Process "httpd"
</Plugin>
EOF
        rlAssert0 "Wrote collectd config for Beaker server" $?
        rlRun "chkconfig collectd on"
        rlServiceStart collectd
        rlPhaseEnd
    fi

    if [[ "$SERVER" != "$(hostname -f)" ]] ; then
        rlPhaseStartTest "SERVERREADY"
        rlRun "rhts-sync-set -s SERVERREADY" 0 "Inventory ready"
        rlPhaseEnd
    fi
}

function LabController()
{
    rlPhaseStartTest "Install Beaker lab controller"
    rlRun "yum install -y beaker-lab-controller$VERSION beaker-lab-controller-addDistro$VERSION"
    rlLog "Installed $(rpm -q beaker-lab-controller)"
    if [[ -n "$EXPECT_BEAKER_GIT_BUILD" && "$(rpm -q beaker-lab-controller)" != *.git.* ]] ; then
        rlDie "Git build was not installed (hint: does destination branch contain latest tags?)"
    fi
    rlPhaseEnd

    rlPhaseStartTest "Configure Beaker lab controller"
    # Configure beaker-proxy config
    generate_proxy_cfg
    echo "add_distro=1" > /etc/sysconfig/beaker_lab_import
    rlPhaseEnd

    rlPhaseStartTest "Configure firewall"
    # XXX we can do better than this
    if [[ $future_distro -eq 0 ]]; then
        rlServiceStop firewalld
    else
        rlServiceStop iptables
    fi
    rlPhaseEnd

    if [[ "$SERVER" != "$(hostname -f)" ]] ; then
        rlPhaseStartTest "Wait for SERVERREADY"
        rlRun "rhts-sync-block -s SERVERREADY -s ABORT $SERVER" 0 "Wait for Server to become ready"
        rlPhaseEnd
    fi

    rlPhaseStartTest "Start services"
    if [[ $future_distro -eq 0 ]]; then
        rlRun -c "systemctl enable tftp.socket"
        rlRun -c "systemctl start tftp.socket"
    else
        rlRun "chkconfig xinetd on" 0
        rlRun "chkconfig tftp on" 0
        rlServiceStart xinetd
    fi

    # There is beaker-transfer as well but it's disabled by default
    for service in httpd beaker-proxy beaker-watchdog beaker-provision ; do
        rlRun "chkconfig $service on" 0
        rlServiceStart $service
    done
    rlPhaseEnd

    if [ -n "$ENABLE_BEAKER_PXEMENU" ] ; then
        rlPhaseStartTest "Enable PXE menu"
        cat >/etc/cron.hourly/beaker_pxemenu <<"EOF"
#!/bin/bash
exec beaker-pxemenu -q
EOF
        chmod 755 /etc/cron.hourly/beaker_pxemenu
        rlAssert0 "Created /etc/cron.hourly/beaker_pxemenu" $?
        rlPhaseEnd
    fi

    rlPhaseStartTest "Configuring apache for WebDav DELETE"
    rlRun "mkdir /var/www/auth" 0
    local user=log-delete realm="$(hostname -f)" password=password
    echo "$user:$realm:$(echo -n "$user:$realm:$password" | md5sum - | cut -d' ' -f1)" >/var/www/auth/.digest_pw
    rlAssert0 "Populated digest password file" $?
    rlLog "Contents of digest password file: $(cat /var/www/auth/.digest_pw)"
    rlLog "Adding DAV configuration to apache conf"
    cat >/etc/httpd/conf.d/beaker-log-delete.conf <<EOF
<DirectoryMatch "/var/www/(beaker/logs|html/beaker\-logs)">
        Options Indexes Multiviews
        Order allow,deny
        Allow from all

        <LimitExcept GET HEAD>
                Dav On
                AuthType Digest
                AuthDigestDomain /var/www/beaker/logs/
                AuthDigestProvider file
                AuthUserFile /var/www/auth/.digest_pw
                Require user log-delete
                AuthName "$(hostname -f)"
        </LimitExcept>
</DirectoryMatch>
EOF
    rlAssert0 "Wrote WebDav DELETE config for Beaker lab controller" $?
    rlLog "Restarting Apache"
    rlServiceStop httpd
    rlServiceStart httpd
    rlPhaseEnd
    if [ -n "$ENABLE_COLLECTD" ] ; then
        rlPhaseStartTest "Enable collectd for metrics collection"
        rlRun "yum install -y collectd"
        cat >/etc/collectd.d/beaker-lab-controller.conf <<EOF
LoadPlugin processes
LoadPlugin write_graphite
<Plugin write_graphite>
  <Carbon>
    Host "$GRAPHITE_SERVER"
    Port "${GRAPHITE_PORT:-2023}"
    Prefix "${GRAPHITE_PREFIX:+$GRAPHITE_PREFIX/}host/"
  </Carbon>
</Plugin>
<Plugin processes>
  Process "beaker-proxy"
  Process "beaker-provisio"
  Process "beah_dummy.py"
</Plugin>
EOF
        rlAssert0 "Wrote collectd config for Beaker lab controller" $?
        rlRun "chkconfig collectd on"
        rlServiceStart collectd
        rlPhaseEnd
    fi
}

rlJournalStart

if [[ "$(getenforce)" == "Enforcing" ]] ; then
    rlLogWarning "SELinux in enforcing mode, Beaker is not likely to work!"
fi

if $(echo $CLIENTS | grep -q $(hostname -f)); then
    rlLog "Running as Lab Controller using Inventory: ${SERVERS}"
    SERVER=$(echo $SERVERS | awk '{print $1}')
    Client
    LabController
fi

if $(echo $SERVERS | grep -q $(hostname -f)); then
    rlLog "Running as Inventory using Lab Controllers: ${CLIENTS}"
    Client
    Inventory
fi

if [ -z "$SERVERS" -o -z "$CLIENTS" ]; then
    rlLog "Inventory=${SERVERS} LabController=${CLIENTS} Assuming Single Host Mode."
    CLIENTS=$STANDALONE
    SERVERS=$STANDALONE
    SERVER=$(echo $SERVERS | awk '{print $1}')
    Client
    Inventory
    LabController
fi

rlJournalEnd
rlJournalPrintText
