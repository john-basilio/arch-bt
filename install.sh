#!/usr/bin/env bash

# Enable case-insensitive matching
shopt -s nocasematch

echo ""
echo "                 _____   _____ _    _        ____ _______ "
echo "           /\   |  __ \ / ____| |  | |      |  _ \__   __|"
echo "          /  \  | |__) | |    | |__| |______| |_) | | |  "
echo "         / /\ \ |  _  /| |    |  __  |______|  _ <  | |  "
echo "        / ____ \| | \ \| |____| |  | |      | |_) | | |  "
echo "       /_/    \_\_|  \_\\\_____|_|  |_|      |____/  |_|   "
echo "      "
echo "      "
echo ""
echo "      Github: github.com/john-basilio"
echo "      Repo:   github.com/john-basilio/arch-bt"
echo ""
echo "      Note: Please read the preparation instructions from my github repo. Highly recommended for newbies like me."
echo ""
echo "      If you haven't done it, please use cfdisk to make an EFI partition with type \"EFI system\" and your ROOT partition with type \"Linux Filesystem\"."
echo "      Some options that you might be interested are pre-defined (The kernel, cpu driver,gpu driver, and bootloader for example)."
echo "      Feel free to visit my repo and edit the script to suit your needs."
echo ""
echo ""

######################################
# Confirmation before starting the script
read -p "       Do you still want to continue? [y/n]" startScript

if [[ $startScript =~ ^[Yy]$ ]]; then
    echo "      -------------------------------------------------"
    echo "                        Proceeding..."
    echo "      -------------------------------------------------"
else
    exit
fi

echo "      --------------------------------------------------------------------------"
echo "              Making necessary preparation ands downloading updates..."
echo "      --------------------------------------------------------------------------"
pacman -Sy
pacman-key --init
pacman-key --populate
pacman -S archlinux-keyring --noconfirm --needed
pacman -S btrfs-progs  --noconfirm --needed

#<------------------------------------->

# User creation

read -p "$(echo -e '\n \n       Enter your USERNAME: \n')" USERNAME
read -p "$(echo -e '\n \n       Enter your USER PASSWORD: \n')" USERPASS
read -p "$(echo -e '\n \n       Enter your HOST NAME: \n')" HOSTNAME
read -p "$(echo -e '\n \n       Enter your ROOT PASSWORD: \n        (Different from USER PASSWORD) \n')" ROOTPASS

echo "      ------------------------------------------------------------------------------------------"
echo "              Username: $USERNAME, User Password: $USERPASS, Root Password: $ROOTPASS"
echo "      ------------------------------------------------------------------------------------------"
echo ""
echo ""
echo "      -------------------------------------------------------------"
echo "              Proceeding with defining target partitions..."
echo "      -------------------------------------------------------------"
echo ""
echo ""

#<------------------------------------->

# Indented lsblk function
indent() {
  local indentSize=2
  local indent=1
  if [ -n "$1" ]; then indent=$1; fi
  pr -to $(($indent * $indentSize))
}
lsblk | indent 15

# Defining partitions
read -p "$(echo -e '\n       Enter your EFI partition (/dev/$partition): \n')" EFIPARTITION
read -p "$(echo -e '\n       Enter your ROOT partition (/dev/$partition): \n')" ROOTPARTITION

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
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@ $ROOTPARTITION /mnt
mkdir /mnt/home
mkdir -p /mnt/var/cache/pacman/pkg
mkdir -p /mnt/var/log
mkdir /mnt/.snapshots
mkdir /mnt/boot
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@home $ROOTPARTITION /mnt/home
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@pkg $ROOTPARTITION /mnt/var/cache/pacman/pkg
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@log $ROOTPARTITION /mnt/var/log
mount -o noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@snapshots $ROOTPARTITION /mnt/.snapshots
mount $EFIPARTITION /mnt/boot


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

# Installing base system
echo "      -------------------------------------------------"
echo "               Installing the base system..."
echo "      -------------------------------------------------"
pacstrap /mnt base base-devel #--noconfirm --needed

# Installing the kernel
echo "      -------------------------------------------------"
echo "                  Installing the kernel"
echo "      -------------------------------------------------"
pacstrap /mnt linux linux-firmware --noconfirm --needed

#Install packages
echo "      -------------------------------------------------"
echo "                  Installing the necessary packages"
echo "      -------------------------------------------------"
pacstrap /mnt iwd networkmanager network-manager-applet wireless_tools nano intel-ucode git firefox xf86-video-nouveau mesa grub --noconfirm --needed

# Generate fstab entries for each subvolume
echo "      -------------------------------------------------"
echo "                     Generating fstab"
echo "      -------------------------------------------------"

UUID=$(blkid "$ROOTPARTITION" | awk '/^\/dev\//{print $2}' | cut -d'"' -f2)

echo "UUID=$UUID /mnt btrfs defaults,noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@ 0 0" >> /mnt/etc/fstab
echo "UUID=$UUID /mnt/home btrfs defaults,noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@home 0 0" >> /mnt/etc/fstab
echo "UUID=$UUID /mnt/var/cache/pacman/pkg btrfs defaults,noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@pkg 0 0" >> /mnt/etc/fstab
echo "UUID=$UUID /mnt/var/log btrfs defaults,noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@log 0 0" >> /mnt/etc/fstab
echo "UUID=$UUID /mnt/.snapshots btrfs defaults,noatime,compress=zstd:5,discard=async,space_cache=v2,subvol=@snapshots 0 0" >> /mnt/etc/fstab

# Installing and configuring grub
echo "      -------------------------------------------------"
echo "                      Configuring GRUB"
echo "      -------------------------------------------------"
grub-install --target=x86_64-efi --efi-directory=$EFIPARTITION --bootloader-id="I use ARCH btw."
grub-mkconfig -o /mnt/boot/grub/grub.cfg

echo "      ------------------------------------------------------------------------------------------------"
echo "                  Done configuring grub, proceeding with final configurations with chroot"
echo "      ------------------------------------------------------------------------------------------------"
# Creating a new script for final configurations to run on chroot
cat <<REALEND > /mnt/next.sh
useradd -m $USERNAME
usermod -aG wheel,storage,power,audio $USERNAME
echo $USERNAME:$USERPASS | chpasswd
echo "root:$ROOTPASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "        Setting up language and locale"
echo "-------------------------------------------------"
sed -i 's/^#en_PH.UTF-8 UTF-8/en_PH.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	arch.localdomain	arch
EOF

echo "-------------------------------------------------"
echo "          Display and Audio Drivers"
echo "-------------------------------------------------"

pacman -S xorg pulseaudio --noconfirm --needed

systemctl enable NetworkManager 

pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm --needed
systemctl enable lightdm


echo "-------------------------------------------------"
echo "      Install Complete, You may reboot now."
echo "-------------------------------------------------"
echo ""
echo "Thanks for using my script!"
echo "Also check out my repo for credits!"

REALEND

arch-chroot /mnt sh next.sh