#!/bin/bash

### DEFINE THESE VARIABLES:

# Text file with password used for backups (it should be owned by root and have permissions set with chmod 600).
BACKUP_SECRET=$(cat /usr/local/etc/backup_secret.txt)

# Volume group. Run "sudo lvs" to check if not sure.
VG="vgbox" 

# Logical volume inside volume group you want to backup. Run "sudo lvs" to check if not sure.
LV="root"

# Output folder (include slash at the end). Ideally it should be on a separate disk and (ofc) MUST NOT be on the logical volume you want to backup.
OUTPUT_FOLDER="/mnt/data/backups/"

### END OF USER VARIABLES

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

# Bash only handles integers without decimal points, so here's a workaround. We'll check the size of LV, then truncate everything after the decimal point.
declare -i LV_SIZE=$(lvs $VG/$LV | awk 'FNR==2 {print $4}' | cut -d. -f1 )
# Now we'll calculate the size for the snapshot (5% fo the partition size).
SNAP_SIZE=$((LV_SIZE*5/100))

# It doesn't cost much to make it pretty.
INFO="\033[1;32m" # light green
ERROR="\033[1;31m" # light red
NC="\033[0m" # no color

printf "### ${INFO}LVM backup script V0.1${NC} ###\n"

printf "${INFO} Creating snapshot... ${NC}\n"
printf "Name: snap-${LV}
Size: ${SNAP_SIZE}g
Partition size (approximate): ${LV_SIZE}g\n"
lvcreate -s -n snap-${LV} -L ${SNAP_SIZE}g ${VG}/${LV}

printf "${INFO} Writing image... ${NC}\n"
printf "Output file: ${OUTPUT_FOLDER}snap-${LV}-${LV_SIZE}g-encrypted-"`date +"%d-%m-%Y"`".img.gz\n"
dd if=/dev/${VG}/snap-${LV} | pv -s ${LV_SIZE}G | pigz | openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000 -salt -pass pass:${BACKUP_SECRET} -out ${OUTPUT_FOLDER}/snap-${LV}-${LV_SIZE}g-encrypted-"`date +"%d-%m-%Y"`".img.gz

printf "${INFO} Removing snapshot... ${NC}\n"
lvremove --force ${VG}/snap-${LV}
