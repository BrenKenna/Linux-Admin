#!/bin/bash


###################################################
###################################################
# 
# Setup 3 Sets of Loopback Devices for ZFS Pools
# 
###################################################
###################################################

# Vars
DATE_NOW=$(date)
ZFS_TEST_HOME=/media/zfs_test
DEVICE_HOME=${ZFS_TEST_HOME}/devices
ZFS_MOUNT=/mnt/zfs_test/zfs_pool
mkdir -p $ZFS_MOUNT $DEVICE_HOME
cd $DEVICE_HOME


# Setup the three sets of sparse files
echo -e "\n\\nSetting up 3 sets of 10 devices for ZFS pool:\\t$DATE_NOW"
for i in {1..3}
do
    # Setup ten devices for this pool
    mkdir -p zfs-set$i
    echo -e "\\nSetting device set:\\t$i"
    for j in {1..10}
    do
        # Setup spares file and loopback device
        dd of=$DEVICE_HOME/zfs-set${i}/disk-${j}.img bs=2M seek=1K count=0
        losetup -f $DEVICE_HOME/zfs-set${i}/disk-${j}.img
    done
    echo -e "\\nCompleted device set:\\t$i"
done

# Note completion
DATE_NOW=$(date)
echo -e "\\nProcess completed displaying loopback devices:\\t$DATE_NOW"
losetup -a | grep -i "zfs-set"