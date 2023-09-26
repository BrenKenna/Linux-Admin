#!/bin/bash


##############################
##############################
# 
# Config Primary
#
# https://documentation.suse.com/ses/7/html/ses-all/deploy-salt.html
# 
##############################
##############################


# Open ports 4505-4506 to minions
zypper in -y salt-master
systemctl enable salt-master.service
systemctl start salt-master.service


#############################
#############################
#
# Configure Secondary
#
#############################
#############################


zypper in -y salt-minion
systemctl enable salt-minion.service
systemctl start salt-minion.service