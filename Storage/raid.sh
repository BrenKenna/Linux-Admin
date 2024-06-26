#!/bin/bash

##########################################################################################
##########################################################################################
# 
# - Create RAID Array from Logical Devices whose blocks map back
#  to sparse files
# 
# - Restart => Extra steps with loop back devices
#
# - Drop, replace and add spare drives
# 
# Useful Links:
# 1). https://www.jeffgeerling.com/blog/2021/htgwa-create-raid-array-linux-mdadm
# 
##########################################################################################
##########################################################################################


###############################################################
###############################################################
#
# 1). Create RAID Array from Logical Devices
#
###############################################################
###############################################################


#########################################
#########################################
#
# a). Create Logical Devices
# 
#########################################
#########################################

# Config directory
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array
mkdir -p $DEVICE_HOME $RAID_MOUNT && cd ${RAID_TEST_HOME}


# Configure 10 logical devices
for i in {1..10}
do
    dd of=${DEVICE_HOME}/disk-${i}.img bs=2M seek=1K count=0
    losetup -f ${DEVICE_HOME}/disk-${i}.img
done


# Check
losetup -a

"""
/dev/loop1: [2064]:54064 (/media/raid/devices/disk-2.img)
/dev/loop8: [2064]:54135 (/media/raid/devices/disk-9.img)
/dev/loop6: [2064]:54101 (/media/raid/devices/disk-7.img)
/dev/loop4: [2064]:54099 (/media/raid/devices/disk-5.img)
/dev/loop2: [2064]:54081 (/media/raid/devices/disk-3.img)
/dev/loop0: [2064]:13 (/media/raid/devices/disk-1.img)
/dev/loop9: [2064]:54173 (/media/raid/devices/disk-10.img)
/dev/loop7: [2064]:54119 (/media/raid/devices/disk-8.img)
/dev/loop5: [2064]:54100 (/media/raid/devices/disk-6.img)
/dev/loop3: [2064]:54092 (/media/raid/devices/disk-4.img)

"""

# Test read and write on device
mkdir -p /mnt/raid_test/loop1
mkfs -t xfs ${DEVICE_HOME}/disk-1.img
mount -o loop,rw /dev/loop1 /mnt/raid_test/loop1
df -h /mnt/raid_test/loop1
umount /mnt/raid_test/loop1

"""
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop10     2.0G   35M  2.0G   2% /mnt/raid_test/loop1
"""


#########################################
#########################################
# 
# b). Create RAID Array
# 
#########################################
#########################################

# Vars
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array


# Create RAID-6 from "Drives"
DRIVES_FOR_RAID=$(losetup -a | awk -F ':' '{print $1}' | xargs)
mdadm \
    --create /dev/md0 \
    --level 6 \
    --raid-devices=10 \
    ${DRIVES_FOR_RAID}

'''
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
'''


# Inspect Array
mdadm --detail --scan --verbose &>> /etc/mdadm/mdadm.conf
mdadm --query /dev/md0
mdadm --detail /dev/md0

'''

--> Persist the md0 array
ARRAY /dev/md0 level=raid6 num-devices=10 metadata=1.2 name=LAPTOP-SL02RC0C:0 UUID=c30ebde2:13e3abda:1af989b7:be857705
   devices=/dev/loop0,/dev/loop1,/dev/loop2,/dev/loop3,/dev/loop4,/dev/loop5,/dev/loop6,/dev/loop7,/dev/loop8,/dev/loop9

--> General info
/dev/md0: 15.98GiB raid6 10 devices, 0 spares

---> Admin details

/dev/md0:
           Version : 1.2
     Creation Time : Tue Aug 22 12:57:16 2023
        Raid Level : raid6
        Array Size : 16752640 (15.98 GiB 17.15 GB)
     Used Dev Size : 2094080 (2045.00 MiB 2144.34 MB)
      Raid Devices : 10
     Total Devices : 10
       Persistence : Superblock is persistent

       Update Time : Tue Aug 22 12:58:15 2023
             State : clean
    Active Devices : 10
   Working Devices : 10
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : LAPTOP-SL02RC0C:0  (local to host LAPTOP-SL02RC0C)
              UUID : c30ebde2:13e3abda:1af989b7:be857705
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
       2       7        6        2      active sync   /dev/loop6
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
       9       7        3        9      active sync   /dev/loop3

'''


# Format array & mount
file ${DEVICE_HOME}/disk-2.img
file /dev/md0
mkfs -t xfs /dev/md0

mkdir -p /mnt/raid_test/raid_array
mount -o rw /dev/md0 /mnt/raid_test/raid_array
df -h /mnt/raid_test/raid_array

'''
--> RAID FS

meta-data=/dev/md0               isize=512    agcount=16, agsize=261760 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=0, rmapbt=0, reflink=0
data     =                       bsize=4096   blocks=4188160, imaxpct=25
         =                       sunit=128    swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0


--> Disk Space

Filesystem      Size  Used Avail Use% Mounted on
/dev/md0         16G   50M   16G   1% /mnt/raid_test/raid_array

'''



###############################################################
###############################################################
#
# 2). Restart the Array
#
###############################################################
###############################################################


# Vars
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array


# Stop the array
umount /mnt/raid_test/raid_array
mdadm --stop /dev/md0

'''
mdadm: stopped /dev/md0
'''


# Assemble from etc config or, from device mapping
DRIVES_FOR_RAID=$(ls /dev/loop* | grep -v "control" | xargs)
mdadm --assemble /dev/md0
mdadm --assemble scan --uuid="4c7688a6-c145-4027-81f6-6baf372109a4"
mdadm --assemble /dev/md0 ${DRIVES_FOR_RAID}

'''

mdadm: /dev/md0 has been started with 10 drives.

'''



###############################################################
###############################################################
# 
# 3). Persistent Mount
#
# -> More work to do with logical devices
# -> Shell script to find devices first
# 
###############################################################
###############################################################


# Vars
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array


# Block ID attributes
blkid | grep -ie "loop" -ie "md0"
echo -e "UUID=4c7688a6-c145-4027-81f6-6baf372109a4 /mnt/raid_test/raid_array xfs defaults 0 0" > /etc/fstab


'''
--> RAID Array
/dev/md0: UUID="4c7688a6-c145-4027-81f6-6baf372109a4" TYPE="xfs"


--> Drives
/dev/loop0: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="ed4157d8-8580-9f1e-5047-89250241f531" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop1: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="451f232d-280f-3278-d9cc-7f51e570bb03" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop2: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="b9a6a8d1-dfda-128f-a7bb-d420cd54d5ac" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop3: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="3fad550c-5e5f-02bb-4289-e6b082daa8db" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop4: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="3f83a819-2b0a-91dd-f738-fc300b198d3e" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop5: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="e4932efd-a266-a66f-f667-c63df43454b7" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop6: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="2e2d11c2-89ad-5937-5252-8e7ee7541a9d" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop7: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="c162728c-53f9-0183-b60f-99388d4de1c0" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop8: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="ebd7bc2b-a045-204e-1293-dd7670d86f6b" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop9: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="0a069ba4-b413-4ea0-8107-18c2ba231910" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"


--> Following a restart
/dev/loop0: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="ed4157d8-8580-9f1e-5047-89250241f531" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"
/dev/loop1: UUID="c30ebde2-13e3-abda-1af9-89b7be857705" UUID_SUB="451f232d-280f-3278-d9cc-7f51e570bb03" LABEL="LAPTOP-SL02RC0C:0" TYPE="linux_raid_member"

'''


# Test write
mount -o rw /dev/md0 $RAID_MOUNT
df -h $RAID_MOUNT
fallocate -l 5G $RAID_MOUNT/5-GB-File


# Check if file exists after restart
for i in {1..10}; do losetup -f ${DEVICE_HOME}/disk-${i}.img; done
mdadm --assemble /dev/md0
mount -o rw /dev/md0 $RAID_MOUNT
df -h $RAID_MOUNT
ls -lh $RAID_MOUNT

'''

--> Before lookup files were modified
-rw-r--r-- 1 root root 2.0G Aug 22 13:55 disk-1.img
-rw-r--r-- 1 root root 2.0G Aug 22 13:55 disk-10.img
-rw-r--r-- 1 root root 2.0G Aug 22 13:55 disk-2.img
-rw-r--r-- 1 root root 2.0G Aug 22 13:55 disk-3.img

--> After data is persistent
Filesystem      Size  Used Avail Use% Mounted on
/dev/md0         16G  5.1G   11G  32% /mnt/raid_test/raid_array

total 5.0G
-rw-r--r-- 1 root root 5.0G Aug 22 13:54 5-GB-File
'''



############################################
############################################
# 
# 4). Persistennce Options
# 
#
# References:
# 1). https://www.baeldung.com/linux/run-script-on-startup
# 
############################################
############################################


# Vars
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array


# Init directive
vi /etc/init.d/raidArray-serviceWrapper.sh
chmod +x raidArray-serviceWrapper.sh
update-rc.d raidArray-serviceWrapper.sh defaults

service raidArray-serviceWrapper.sh start
service raidArray-serviceWrapper.sh enable

'''
#!/bin/sh
# chkconfig: 345 99 10
case "$1" in
  start)
    # Executes our script
    sudo sh /media/raid/reboot-raid-array.sh
    ;;
  *)
    ;;
esac
exit 0

'''


# With crontab
crontab -e
@reboot sh /media/raid/reboot-raid-array.sh


# Create a directive for rebooting array
vi /etc/systemd/system/raid-array.service
systemctl enable raid-array

'''

--> Trial system directive unit

[Unit]
Description=Reboot message systemd service.

[Service]
Type=simple
ExecStart=/bin/bash /media/raid/reboot-raid-array.sh

[Install]
WantedBy=multi-user.target


--> Enabled service
Created symlink /etc/systemd/system/multi-user.target.wants/raid-array.service → /etc/systemd/system/raid-array.service.

'''


############################################
############################################
# 
# 5). Replacement & Hot Spare Drivess
# 
#
# References:
# 1). https://www.baeldung.com/linux/run-script-on-startup
# 
############################################
############################################


##################################
##################################
# 
# a). Setup Logical Drives
# 
##################################
##################################


# Create a replacement, and a spare
dd of=${DEVICE_HOME}/disk-replacement.img bs=2M seek=1K count=0
losetup -f ${DEVICE_HOME}/disk-replacement.img

dd of=${DEVICE_HOME}/disk-spare.img bs=2M seek=1K count=0
losetup -f ${DEVICE_HOME}/disk-spare.img

losetup -a 

'''

/dev/loop10: [2064]:54193 (/media/raid/devices/disk-replacement.img)
/dev/loop11: [2064]:54201 (/media/raid/devices/disk-spare.img)

'''


##################################
##################################
# 
# b). Replace "Failed" Drive
# 
##################################
##################################


# Vars and umount
FAILED_DRIVE="/dev/loop3"
REPLACEMENT_DRIVE="/dev/loop10"
SPARE_DRIVE="/dev/loop11"

umount /mnt/raid_test/raid_array


# Mark one as failed, and remove from array
mdadm --manage /dev/md0 --fail ${FAILED_DRIVE}
cat /proc/mdstat
mdadm --detail /dev/md0

mdadm --manage /dev/md0 --remove ${FAILED_DRIVE}

'''

--> Failed
mdadm: set /dev/loop3 faulty in /dev/md0


--> State after fail

Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md0 : active raid6 loop1[0] loop3[9](F) loop5[8] loop7[7] loop9[6] loop0[5] loop2[4] loop4[3] loop6[2] loop8[1]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/9] [UUUUUUUUU_]

unused devices: <none>

State : clean, degraded
    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
       2       7        6        2      active sync   /dev/loop6
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
       -       0        0        9      removed

       9       7        3        -      faulty   /dev/loop3

--> Removal
mdadm: hot removed /dev/loop3 from /dev/md0

'''


# Replace
mdadm --manage /dev/md0 --add ${REPLACEMENT_DRIVE}
watch cat /proc/mdstat

'''

--> Adding drive

mdadm: added /dev/loop10


--> Adding new drive
Every 2.0s: cat /proc/mdstat                                                          LAPTOP-SL02RC0C: Wed Aug 23 15:03:41 2023

Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md0 : active raid6 loop10[10] loop1[0] loop5[8] loop7[7] loop9[6] loop0[5] loop2[4] loop4[3] loop6[2] loop8[1]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/9] [UUUUUUUUU_]
      [=======>.............]  recovery = 36.1% (757148/2094080) finish=0.7min speed=29121K/sec



State : clean, degraded, recovering
Rebuild Status : 68% complete

    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
       2       7        6        2      active sync   /dev/loop6
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
      10       7       10        9      spare rebuilding   /dev/loop10

'''


# Add the spare drive to array
SECOND_FAILED_DRIVE="/dev/loop6"
mdadm --manage /dev/md0 --add ${SPARE_DRIVE}

mdadm --manage /dev/md0 --fail ${SECOND_FAILED_DRIVE}
mdadm --manage /dev/md0 --remove ${SECOND_FAILED_DRIVE}

cd $RAID_MOUNT
md5sum -c 5-GB-File.md5sum


'''
mdadm: added /dev/loop11


       Update Time : Wed Aug 23 15:07:11 2023
             State : clean
    Active Devices : 10
   Working Devices : 11
    Failed Devices : 0
     Spare Devices : 1


    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
       2       7        6        2      active sync   /dev/loop6
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
      10       7       10        9      active sync   /dev/loop10

      11       7       11        -      spare   /dev/loop11


--> Watch spare take place of failed drive loop 3 & 6 are gone
    => Replaced with loop 10 and 11

mdadm: set /dev/loop6 faulty in /dev/md0
mdadm: hot removed /dev/loop6 from /dev/md0

    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
      11       7       11        2      active sync   /dev/loop11
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
      10       7       10        9      active sync   /dev/loop10


--> Test file integrity after disaster
5-GB-File: OK
'''


###########################################################
###########################################################
# 
# Logicall Partition Array Device
# 
###########################################################
###########################################################

# Config directory
RAID_TEST_HOME=/media/raid
DEVICE_HOME=${RAID_TEST_HOME}/devices
RAID_MOUNT=/mnt/raid_test/raid_array
mkdir -p $DEVICE_HOME $RAID_MOUNT && cd ${RAID_TEST_HOME}


# Configure 10 logical devices
for i in {1..10}
do
    dd of=${DEVICE_HOME}/disk-${i}.img bs=2M seek=1K count=0
    losetup -f ${DEVICE_HOME}/disk-${i}.img
done


# Sanity check
losetup -a

'''
/dev/loop1: [2064]:7455 (/media/raid/devices/disk-2.img)
/dev/loop8: [2064]:8231 (/media/raid/devices/disk-9.img)
/dev/loop6: [2064]:8211 (/media/raid/devices/disk-7.img)
/dev/loop4: [2064]:8198 (/media/raid/devices/disk-5.img)
/dev/loop2: [2064]:7458 (/media/raid/devices/disk-3.img)
/dev/loop0: [2064]:7436 (/media/raid/devices/disk-1.img)
/dev/loop9: [2064]:8235 (/media/raid/devices/disk-10.img)
/dev/loop7: [2064]:8220 (/media/raid/devices/disk-8.img)
/dev/loop5: [2064]:8200 (/media/raid/devices/disk-6.img)
/dev/loop3: [2064]:8196 (/media/raid/devices/disk-4.img)
'''


# Create array, and sanity check
DRIVES_FOR_RAID=$(losetup -a | awk -F ':' '{print $1}' | xargs)
mdadm \
    --create /dev/md0 \
    --level 6 \
    --raid-devices=10 \
    ${DRIVES_FOR_RAID}

cat /proc/mdstat
mdadm -D /dev/md0

'''

mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.

Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md0 : active raid6 loop3[9] loop5[8] loop7[7] loop9[6] loop0[5] loop2[4] loop4[3] loop6[2] loop8[1] loop1[0]
      16752640 blocks super 1.2 level 6, 512k chunk, algorithm 2 [10/10] [UUUUUUUUUU]

unused devices: <none>


/dev/md0:
           Version : 1.2
     Creation Time : Thu May 16 15:32:53 2024
        Raid Level : raid6
        Array Size : 16752640 (15.98 GiB 17.15 GB)
     Used Dev Size : 2094080 (2045.00 MiB 2144.34 MB)
      Raid Devices : 10
     Total Devices : 10
       Persistence : Superblock is persistent

       Update Time : Thu May 16 17:05:31 2024
             State : clean
    Active Devices : 10
   Working Devices : 10
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : bkenna-xps:0  (local to host bkenna-xps)
              UUID : 4f23a47f:eba3bc71:fa03d77b:1862dd90
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       7        1        0      active sync   /dev/loop1
       1       7        8        1      active sync   /dev/loop8
       2       7        6        2      active sync   /dev/loop6
       3       7        4        3      active sync   /dev/loop4
       4       7        2        4      active sync   /dev/loop2
       5       7        0        5      active sync   /dev/loop0
       6       7        9        6      active sync   /dev/loop9
       7       7        7        7      active sync   /dev/loop7
       8       7        5        8      active sync   /dev/loop5
       9       7        3        9      active sync   /dev/loop3

'''

# Configure physical volume, multiple instead?
RAID_DEVICE="/dev/md0"
pvcreate ${RAID_DEVICE}

pvs; echo -e "\n"; pvdisplay

'''
Physical volume "/dev/md0" successfully created.

PV         VG Fmt  Attr PSize   PFree
  /dev/md0      lvm2 ---  <15.98g <15.98g


  "/dev/md0" is a new physical volume of "<15.98 GiB"
  --- NEW Physical volume ---
  PV Name               /dev/md0
  VG Name
  PV Size               <15.98 GiB
  Allocatable           NO
  PE Size               0
  Total PE              0
  Free PE               0
  Allocated PE          0
  PV UUID               257qdD-OfTQ-J6xL-3VeK-ZsDq-TA8U-zaOz4W

--> After creation of 4 volumes, see there is room for another of same size
  PV         VG  Fmt  Attr PSize  PFree
  /dev/md0   vg0 lvm2 a--  15.97g 3.97g

--> Create another see below
  PV         VG  Fmt  Attr PSize  PFree
  /dev/md0   vg0 lvm2 a--  15.97g 996.00m
  
'''

# Create volume group
vgcreate vg0 /dev/md0

vgs; echo -e "\n"; vgdisplay

'''
Volume group "vg0" successfully created

  VG  #PV #LV #SN Attr   VSize  VFree
  vg0   1   0   0 wz--n- 15.97g 15.97g

  --- Volume group ---
  VG Name               vg0
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  1
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                0
  Open LV               0
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               15.97 GiB
  PE Size               4.00 MiB
  Total PE              4089
  Alloc PE / Size       0 / 0
  Free  PE / Size       4089 / 15.97 GiB
  VG UUID               RnupIr-LhTJ-5L0N-1C8F-wq3E-KQet-CdtejW

--> After 5th
  VG  #PV #LV #SN Attr   VSize  VFree
  vg0   1   5   0 wz--n- 15.97g 996.00m

  --- Volume group ---
  VG Name               vg0
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  14
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                5
  Open LV               5
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               15.97 GiB
  PE Size               4.00 MiB
  Total PE              4089
  Alloc PE / Size       3840 / 15.00 GiB
  Free  PE / Size       249 / 996.00 MiB
  VG UUID               RnupIr-LhTJ-5L0N-1C8F-wq3E-KQet-CdtejW
'''


# Create logical volumes
lvcreate --zero n -n data0 -L 3G vg0
lvcreate  --zero n -n data1 -L 3G vg0

lvcreate --zero n -n logging0 -L 3G vg0
lvcreate  --zero n -n logging1 -L 3G vg0

lvcreate  --zero n -n cache0 -L 3G vg0

lvs; echo -e "\n"; lvdisplay

'''
WARNING: Logical volume vg0/data0 not zeroed.
  Logical volume "data0" created.

WARNING: Logical volume vg0/data1 not zeroed.
  Logical volume "data1" created.

WARNING: Logical volume vg0/logging0 not zeroed.
  Logical volume "logging0" created.

WARNING: Logical volume vg0/logging1 not zeroed.
  Logical volume "logging1" created.

WARNING: Logical volume vg0/cache0 not zeroed.
  Logical volume "cache0" created.

LV       VG  Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  data     vg0 -wi-a----- 3.00g
  data0    vg0 -wi-a----- 3.00g
  logging0 vg0 -wi-a----- 3.00g
  logging1 vg0 -wi-a----- 3.00g


  --- Logical volume ---
  LV Path                /dev/vg0/data0
  LV Name                data0
  VG Name                vg0
  LV UUID                YnqtEy-QEN5-yVZ3-eK6k-QuJP-LuLP-7P5kdm
  LV Write Access        read/write
  LV Creation host, time bkenna-xps, 2024-05-16 15:57:17 +0100
  LV Status              available
  # open                 0
  LV Size                3.00 GiB
  Current LE             768
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:0

  --- Logical volume ---
  LV Path                /dev/vg0/data1
  LV Name                data1
  VG Name                vg0
  LV UUID                tY4DfH-Wa46-seKI-VFCm-U2un-8zXy-38FLHR
  LV Write Access        read/write
  LV Creation host, time bkenna-xps, 2024-05-16 15:58:33 +0100
  LV Status              available
  # open                 0
  LV Size                3.00 GiB
  Current LE             768
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:1

  --- Logical volume ---
  LV Path                /dev/vg0/logging0
  LV Name                logging0
  VG Name                vg0
  LV UUID                uEn8Vv-6GFt-3WM7-1W1V-zod2-Twro-yAOmn0
  LV Write Access        read/write
  LV Creation host, time bkenna-xps, 2024-05-16 15:58:49 +0100
  LV Status              available
  # open                 0
  LV Size                3.00 GiB
  Current LE             768
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:2

  --- Logical volume ---
  LV Path                /dev/vg0/logging1
  LV Name                logging1
  VG Name                vg0
  LV UUID                SzlJAj-wNmS-TTxg-GVGe-kY9o-cfN5-1VVRlZ
  LV Write Access        read/write
  LV Creation host, time bkenna-xps, 2024-05-16 15:58:52 +0100
  LV Status              available
  # open                 0
  LV Size                3.00 GiB
  Current LE             768
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:3
'''


# Make filesystem on each: 
vgchange -ay vg0 # This and below cause loopback device?
dmsetup mknodes

mkfs.xfs /dev/mapper/vg0-data # would usually be /dev/vg0/data0
mkfs.xfs /dev/mapper/vg0-data1

mkfs.xfs /dev/mapper/vg0-logging0
mkfs.xfs /dev/mapper/vg0-logging1

mkfs.xfs /dev/mapper/vg0-cache0

'''
  4 logical volume(s) in volume group "vg0" now active
  5 logical volume(s) in volume group "vg0" now active

meta-data=/dev/mapper/vg0-logging0 isize=512    agcount=8, agsize=98176 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=785408, imaxpct=25
         =                       sunit=128    swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0


meta-data=/dev/mapper/vg0-cache0 isize=512    agcount=8, agsize=98176 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=785408, imaxpct=25
         =                       sunit=128    swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
'''

# Mount each
for DEV in $(ls /dev/mapper/ | grep "vg0")
do
    NAME=$(echo $DEV | sed 's/vg0-//g')
    mkdir -p /mnt/${NAME}
    mount /dev/mapper/${DEV} /mnt/$NAME
done

df -h

'''
Filesystem                Size  Used Avail Use% Mounted on
/dev/sdb                  251G  2.7G  236G   2% /

/dev/mapper/vg0-data0     3.0G   54M  3.0G   2% /mnt/data0
/dev/mapper/vg0-data1     3.0G   54M  3.0G   2% /mnt/data1
/dev/mapper/vg0-logging0  3.0G   54M  3.0G   2% /mnt/logging0
/dev/mapper/vg0-logging1  3.0G   54M  3.0G   2% /mnt/logging1
/dev/mapper/vg0-cache0    3.0G   54M  3.0G   2% /mnt/cache0
'''


# Write file and check
fallocate -l 1.5G /mnt/data0/test-file.img
fallocate -l 1G /mnt/data1/test-file.img

fallocate -l 2G /mnt/logging0/test-file.img
fallocate -l 2.5G /mnt/logging1/test-file.img

df -h
'''
Filesystem                Size  Used Avail Use% Mounted on
/dev/mapper/vg0-data0     3.0G  1.6G  1.5G  52% /mnt/data0
/dev/mapper/vg0-data1     3.0G  1.1G  2.0G  36% /mnt/data1
/dev/mapper/vg0-logging0  3.0G  2.1G  957M  69% /mnt/logging0
/dev/mapper/vg0-logging1  3.0G  2.6G  445M  86% /mnt/logging1
'''






