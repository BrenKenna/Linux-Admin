#!/bin/bash


###################################################
###################################################
# 
# Create RAID-6 Array from Each Device Set
# 
###################################################
###################################################

# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
mkdir -p $ZFS_MOUNT $DEVICE_HOME
cd $ZFS_TEST_HOME


# Setup the three sets of sparse files
echo -e "\n\\nSetting up 3 RAID-6 Arrays of 10 loopback devices:\\t$DATE_NOW"
for i in {1..3}
do
    # Create raid array
    RAID_DEVICE="/dev/md$i"
    DRIVES_FOR_RAID=$(losetup -a | grep "set$i" | cut -d ':' -f 1 | xargs)
    echo -e "\\nCreating RAID-6 Array '$RAID_DEVICE' from below drives\\n$DRIVES_FOR_RAID"
    mdadm --create $RAID_DEVICE --level 6 --raid-devices=10 $DRIVES_FOR_RAID
    echo -e "\\nCreation of RAID array completed"
done
echo -e "\n\\nSetup complete:\\t$DATE_NOW"