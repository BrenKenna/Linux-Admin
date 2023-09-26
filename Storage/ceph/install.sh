#!/bin/bash

####################################################################
####################################################################
# 
# CEPH Packages
#
# - Should really have config per node function
#    Salt on key = vCx6ftJYjAt2ZpR
# 
# https://www.videocardbenchmark.net/
# 
#
# References:
# - https://docs.ceph.com/en/pacific/install/index_manual/
# - https://docs.ceph.com/en/pacific/install/manual-deployment/#adding-osds
# - https://docs.ceph.com/en/pacific/install/install-storage-cluster/
# 
# 
# - Monitoring Daemon
#   https://docs.ceph.com/en/pacific/install/manual-deployment/#adding-osds
#   https://docs.ceph.com/en/pacific/mgr/administrator/#mgr-administrator-guide
# 
# 
# - Long form:
#    https://docs.ceph.com/en/pacific/install/manual-deployment/#long-form
# 
####################################################################
####################################################################


#############################################
#############################################
# 
# 1). Install Ceph
# 
#############################################
#############################################


# Install ceph suite
yum update -y && yum install -y g++ cmake
dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf install bind-utils
yum update -y
yum install -y ceph-common libcephfs-devel libcephfs2 python3-ceph-argparse python3-ceph-common python3-cephfs
yum install -y ceph ceph-base cephadm ceph-mgr ceph-mon ceph-fuse ceph-osd ceph-mds ceph-volume cephfs-top cephfs-mirror

''' ---> /etc/yum.repos.d/ceph.repo
https://download.ceph.com/rpm-15.1.0/el7/
https://download.ceph.com/rpm-18.2.0/el9

--> Some dependancies get pulled down from ceph-commons
http://eu.ceph.com/rpm-18.1.0/el9/

[ceph]
name=Ceph packages for $basearch
baseurl=https://download.ceph.com/rpm-18.2.0/el9/x86_64/
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-18.2.0/el9/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://download.ceph.com/rpm-18.2.0/el9/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://download.ceph.com/keys/release.asc
'''



#############################################
#############################################
# 
# 2). Configure Head Node
#
# ba4c0114-9eb0-4602-bf34-9793fe1d9edf
# 
#############################################
#############################################


###########################
###########################
#
# a). Monitor Daemon
# 
###########################
###########################

# Init conf
CEPH_CONF="/etc/ceph/ceph.conf"
clustID=$(uuidgen)
headNode=$(hostname)
ip=$(nslookup $headNode | grep "Address" | tail -n 1 | awk -F ':' '{print $2}' | sed 's/ //g')
echo -e "[global]\nfsid = $clustID" > $CEPH_CONF
echo "mon initial members = $headNode" >> $CEPH_CONF
echo "mon host = $ip" >> $CEPH_CONF
echo """
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
osd journal size = 1024
osd pool default size = 3
osd pool default min size = 2
osd pool default pg num = 333
osd pool default pgp num = 333
osd crush chooseleaf type = 1
""" >> $CEPH_CONF


# Key rings
ceph-authtool --create-keyring /tmp/ceph.mon.keyring \
    --gen-key -n mon. \
    --cap mon 'allow *'


ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring \
    --gen-key -n client.admin \
    --cap mon 'allow *' \
    --cap osd 'allow *' \
    --cap mds 'allow *' \
    --cap mgr 'allow *'


ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring \
    --gen-key -n client.bootstrap-osd \
    --cap mon 'profile bootstrap-osd' \
    --cap mgr 'allow r'

"""
creating /tmp/ceph.mon.keyring
creating /etc/ceph/ceph.client.admin.keyring
creating /var/lib/ceph/bootstrap-osd/ceph.keyring
"""

# Import keys & adjust ownership
ceph-authtool /tmp/ceph.mon.keyring \
    --import-keyring /etc/ceph/ceph.client.admin.keyring
ceph-authtool /tmp/ceph.mon.keyring \
    --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

chown ceph:ceph /tmp/ceph.mon.keyring

"""
importing contents of /etc/ceph/ceph.client.admin.keyring into /tmp/ceph.mon.keyring
importing contents of /var/lib/ceph/bootstrap-osd/ceph.keyring into /tmp/ceph.mon.keyring

"""


# Configure monitor node and start service
monmaptool --create --add $headNode $ip --fsid $clustID /tmp/monmap
sudo -u ceph mkdir /var/lib/ceph/mon/ceph-headNode
sudo -u ceph ceph-mon --mkfs -i $headNode --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

systemctl enable ceph-mon@$headNode
systemctl start ceph-mon@$headNode
systemctl status ceph-mon@$headNode

ceph -s
ls -lh /var/log/ceph/*

"""
Created symlink /etc/systemd/system/ceph-mon.target.wants/ceph-mon@ip-172-31-44-67.eu-west-1.compute.internal.service → /usr/lib/systemd/system/ceph-mon@.service.

monmaptool: monmap file /tmp/monmap
setting min_mon_release = pacific
monmaptool: set fsid to 947fa75c-7285-49b2-974b-1949c4903441
monmaptool: writing epoch 0 to /tmp/monmap (1 monitors)



  cluster:
    id:     947fa75c-7285-49b2-974b-1949c4903441
    health: HEALTH_WARN
            mon is allowing insecure global_id reclaim
            1 monitors have not enabled msgr2

  services:
    mon: 1 daemons, quorum ip-172-31-44-67.eu-west-1.compute.internal (age 3m)
    mgr: no daemons active
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:


-rw-------. 1 ceph ceph  206 Sep 19 16:20 /var/log/ceph/ceph.audit.log
-rw-------. 1 ceph ceph 1.6K Sep 19 16:17 /var/log/ceph/ceph.log
-rw-r--r--. 1 ceph ceph  76K Sep 19 16:21 /var/log/ceph/ceph-mon.ip-172-31-44-67.eu-west-1.compute.internal.log

"""


############################
############################
# 
# c). Manager Daemon
# 
############################
############################


# Manager Daemon => What can done with this dude
mkdir -p /var/lib/ceph/mgr/ceph-$headNode
ceph auth get-or-create mgr.$headNode mon 'allow profile mgr' osd 'allow *' mds 'allow *' \
    > /var/lib/ceph/mgr/ceph-$headNode/keyring
ceph-mgr -i $headNode
mgr active: $headNode

"""
[mgr.ip-172-31-44-67.eu-west-1.compute.internal]
        key = AQB/ywllvWfsChAASIN0MZI/NxTS0l16l/Z/eg==
"""


# Scope out
ceph status



"""

  cluster:
    id:     947fa75c-7285-49b2-974b-1949c4903441
    health: HEALTH_WARN
            mon is allowing insecure global_id reclaim
            1 monitors have not enabled msgr2
            OSD count 0 < osd_pool_default_size 3

  services:
    mon: 1 daemons, quorum ip-172-31-44-67.eu-west-1.compute.internal (age 17m)
    mgr: ip-172-31-44-67.eu-west-1.compute.internal(active, since 56s)
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:

"""


############################
############################
# 
# d). OSD Key
# 
############################
############################



# Copy OSD bootstrap key: 34.250.114.36, 3.250.108.116
scp -pi /home/ec2-user/.ssh/dev-env.pem \
    /var/lib/ceph/bootstrap-osd/ceph.keyring \
    ec2-user@172.31.23.240:/home/ec2-user/


scp -pi /home/ec2-user/.ssh/dev-env.pem \
    /etc/ceph/ceph.conf \
    ec2-user@172.31.23.240:/home/ec2-user/

scp -pi /home/ec2-user/.ssh/dev-env.pem \
    /etc/ceph/ceph.client.admin.keyring \
    ec2-user@172.31.23.240:/home/ec2-user/



#########################################
#########################################
# 
# 2). Configure Storage Node
#
# - OSD
# - MSD = https://docs.ceph.com/en/pacific/install/manual-deployment/#adding-mds
# 
#########################################
#########################################


# Vars
DATE_NOW=$(date)
CEPH_TEST_HOME=/media/ceph_test
DEVICE_HOME=${CEPH_TEST_HOME}/devices
CEPH_MOUNT=/mnt/ceph_test/ceph_pool
mkdir -p $CEPH_MOUNT $DEVICE_HOME
cd $DEVICE_HOME


# Create logical devices for storage node
for j in {1..15}
do
    # Setup spares file and loopback device
    dd of=$DEVICE_HOME/disk-${j}.img bs=2M seek=1K count=0
    losetup -f $DEVICE_HOME/disk-${j}.img
done



# Update permissions
mv /home/ec2-user/ceph.keyring /var/lib/ceph/bootstrap-osd/
chown ceph:ceph /var/lib/ceph/bootstrap-osd/ceph.keyring
mv /home/ec2-user/ceph.conf /etc/ceph/ceph.conf
chown ceph:ceph /etc/ceph/ceph.conf


# Configure secret for OSD
UUID=$(uuidgen)
OSD_SECRET=$(ceph-authtool --gen-print-key)
ID=$(echo "{\"cephx_secret\": \"$OSD_SECRET\"}" | \
   ceph osd new $UUID -i - \
   -n client.bootstrap-osd -k /var/lib/ceph/bootstrap-osd/ceph.keyring)
ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-$ID/keyring \
     --name osd.$ID --add-key $OSD_SECRET

"""
creating /var/lib/ceph/osd/ceph-1/keyring
added entity osd.1 auth(key=AQBg1wll2UjAJhAAbos49cN6fV/aF02Mqb/xDA==)
"""


# Create OSD and enable the service
sudo -u ceph mkdir /var/lib/ceph/osd/ceph-$ID
ceph-osd -i $ID --mkfs --osd-uuid $UUID
systemctl enable ceph-osd@$ID
systemctl start ceph-osd@$ID

tail -n 300 /var/log/ceph/ceph-osd.1.log | less

"""

Created symlink /etc/systemd/system/ceph-osd.target.wants/ceph-osd@1.service → /usr/lib/systemd/system/ceph-osd@.service.

ceph-osd@1.service - Ceph object storage daemon osd.1
     Loaded: loaded (/usr/lib/systemd/system/ceph-osd@.service; enabled; preset: disabled)
     Active: active (running) since Tue 2023-09-19 17:32:45 UTC; 1min 3s ago
    Process: 3049 ExecStartPre=/usr/libexec/ceph/ceph-osd-prestart.sh --cluster ${CLUSTER} --id 1 (code=exited, status=>
   Main PID: 3053 (ceph-osd)
      Tasks: 76
     Memory: 40.2M
        CPU: 824ms
     CGroup: /system.slice/system-ceph\x2dosd.slice/ceph-osd@1.service
             └─3053 /usr/bin/ceph-osd -f --cluster ceph --id 1 --setuser ceph --setgroup ceph
"""



# Prepare volumes
clustID="947fa75c-7285-49b2-974b-1949c4903441"
CEPH_DRIVES=$(ls /dev/loop[0-9]* | xargs)
ceph-volume lvm prepare \
    --data /dev/loop0 \
    --osd-id 2 \
    --cluster-fsid $clustID

"""
ceph-volume lvm prepare: error: unrecognized arguments: /dev/loop1 /dev/loop10 /dev/loop11 /dev/loop12 /dev/loop13 /dev/loop14 /dev/loop2 /dev/loop3 /dev/loop4 /dev/loop5 /dev/loop6 /dev/loop7 /dev/loop8 /dev/loop9 --cluster-id 947fa75c-7285-49b2-974b-1949c4903441


Running command: /bin/ceph-authtool --gen-print-key
Running command: /bin/ceph --cluster ceph --name client.bootstrap-osd --keyring /var/lib/ceph/bootstrap-osd/ceph.keyring osd tree -f json
-->  RuntimeError: The osd ID 1 is already in use or does not exist.

"""

# Activate the OSD
mkfs.xfs /dev/loop1
mount /dev/loop1 /var/lib/ceph/osd/ceph-$ID
ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-$ID/keyring \
     --name osd.$ID --add-key $OSD_SECRET

ceph-volume lvm activate $ID $clustID

"""


"""


###########################

# Alternative
ceph-volume create --bluestore --data /dev/loopX
ceph-osd -i $ID --mkfs --mkkey