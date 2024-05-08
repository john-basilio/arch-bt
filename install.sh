#!/usr/bin/env bash

>

clear

# Indented lsblk function
indent() {
  local indentSize=2
  local indent=1
  if [ -n "$1" ]; then indent=$1; fi
  pr -to $(($indent * $indentSize))
}
lsblk | indent 15

# Defining partitions
read -p "$(echo -e '\n       Enter your EFI partition (/dev/$partition):')" EFIPARTITION
read -p "$(echo -e '\n       Enter your ROOT partition (/dev/$partition):')" ROOTPARTITION

# Final review of partitions
lsblk | indent 25

# Formatting partitions
mkfs.vfat -F 32 $EFIPARTITION
mkfs.btrfs -f $ROOTPARTITION

# Creating and mounting subvolumes
mount $ROOTPARTITION /mnt

echo "      -------------------------------------------------"
echo "                   Creating subvolumes..."
echo "      -------------------------------------------------"
btrfs subvolume create /mnt/{@,@home,@pkg,@log,@snapshots}

umount -l /mnt

# Creating mounting directories for the subvolumes

mkdir -p /mnt/archinstall/boot

mount $EFIPARTITION /mnt/archinstall/boot

mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@ $ROOTPARTITION /mnt/archinstall/

mkdir -p /mnt/archinstall/home

mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@home $ROOTPARTITION /mnt/archinstall/home

mkdir -p /mnt/archinstall/var/cache/pacman/pkg

mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@pkg $ROOTPARTITION /mnt/archinstall/var/cache/pacman/pkg

mkdir -p /mnt/archinstall/var/log

mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@log $ROOTPARTITION /mnt/archinstall/var/log

mkdir /mnt/archinstall/.snapshots
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@snapshots $ROOTPARTITION /mnt/archinstall/.snapshots



if [ $? -eq 0 ]; then
echo "      ---------------------------------------------"
echo "                Success!, proceeding..."
echo "      ---------------------------------------------"
else
echo "      --------------------------------------------"
echo "             Error encountered, exiting..."
echo "      --------------------------------------------"
    exit 1
fi
