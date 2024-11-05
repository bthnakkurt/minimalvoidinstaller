#!/usr/bin/bash

echo "sda or nvme?"
echo "create 3 partitions: first one is efi, second is swap, third is root"
echo "dont forget to select correct type. for first one, select fat32. for second, select swap. for third, select linit filesystem"
read output
bloat="sudo xfsprogs btrfs-progs ipw2100-firmware ipw2200-firmware zd1211-firmware linux-firmware-amd linux-firmware-broadcom base-container-full"
needed="libusb usbutils dbus connman acpi acpid cpio libaio device-mapper kpartx dracut linux-firmware-network linux6.11 linux6.11-headers "
installcommand="chroot /mnt /bin/sh -c"
FSTAB_FILE="/etc/fstab"


fornvme() {
    ## get disk name
    echo "dont mind this"
    device="/dev/nvme0n1"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    cfdisk $device

    ## format disk
    echo "formatting disk"
    mkfs.vfat -F32 ${device}p1
    mkswap ${device}p2
    mkfs.ext4 ${device}p3

    ## mount disk
    echo "mounting disk"
    mount ${device}p3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${device}p1 /mnt/boot/efi
    swapon ${device}p2

    ## download tarball
    downloadtarball

    ## enter chroot
    mountfilesandchroot

    ## install system
    installsystem

    ##setup repo
    setuprepo

    ## prepare system
    prepare

    #setup users
    setupusers

    ## fstab
    bastardfstabnvme

    ##install grub
    installgrub

    ## last touch
    lasttouch

    chroot /mnt /bin/bash
}

forsda() {
    ## get disk name    #working
    echo "dont mind this"
    device="/dev/sda"
    umount -R /mnt/
    umount $device*
    swapoff $device*
    #rm -rf /mnt/*
    #cfdisk $device
    
    ## format disk      #working
    echo "formatting disk"
    mkfs.vfat -F32 ${device}1
    mkswap ${device}2
    mkfs.ext4 ${device}3

    ## mount disk       #working
    echo "mounting disk"
    mount ${device}3 /mnt
    mkdir -p /mnt/boot/efi
    mount ${device}1 /mnt/boot/efi
    swapon ${device}2

    ## download tarball     #working
    downloadtarball

    ## mount to chroot     #working
    mountfilesandchroot

    ##setup repo            #working
    setuprepo

    ## install system       #working
    installsystem

    ## prepare system       #working
    prepare

    #setup users        #working
    setupusers

    ## fstab           #working
    bastardfstabsda

    ##install grub
    installgrub

    ## last touch
    lasttouch

   chroot /mnt /bin/bash
}


downloadtarball() {
    echo "downloading tarball"
    wget -O /tmp/void.tar.xz https://repo-fastly.voidlinux.org/live/current/void-x86_64-ROOTFS-20240314.tar.xz
    tar -xvf /tmp/void.tar.xz -C /mnt
}

mountfilesandchroot() {
    echo "mounting"
    mount -t proc none /mnt/proc
    mount -t sysfs none /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --rbind /run /mnt/run
}

setuprepo() {
    echo "fastest repos installing"
    rm /mnt/usr/share/xbps.d/00-repository-main.conf
    touch /mnt/usr/share/xbps.d/00-repository.conf
    # Append new repository URLs using echo
    echo 'repository=https://repo-fastly.voidlinux.org/current' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-fastly.voidlinux.org/current/nonfree' >> /mnt/usr/share/xbps.d/00-repository-main.conf
    echo 'repository=https://repo-fastly.voidlinux.org/current/multilib' >> /mnt/usr/share/xbps.d/00-repository-main.conf
}

installsystem() {
    sed -i '$a'
    echo "installing system"
    $installcommand "xbps-install -Su xbps"
    $installcommand "xbps-install -u"
    $installcommand "xbps-install $needed"
    $installcommand "xbps-remove $bloat"
}

prepare() {
    echo "preparing system, better get ready"
    $installcommand "mount -t efivarfs none /sys/firmware/efi/efivars"
    vi /mnt/etc/hostname
    vi /mnt/etc/rc.conf
    vi /mnt/etc/default/libc-locales
    $installcommand "xbps-reconfigure -f glibc-locales"
}


setupusers() {
    echo "enter root password 2 times"
    $installcommand "passwd root"
    echo "enter username"
    read username
    $installcommand "useradd -m -G wheel,video,audio $username"
    echo "enter password for $username"
    $installcommand "passwd $username"
}


installgrub() {
    $installcommand "xbps-install refind"
    $installcommand "refind-install"
}

lasttouch() {
    $installcommand "xbps-reconfigure -fa"
}



bastardfstabsda() {
    $installcommand "rm /etc/fstab"
    root_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p3| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
efi_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p1| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
swap_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/nvme0n1p2| awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")

    $installcommand "touch $FSTAB_FILE"
    $installcommand "echo \"$root_UUID / ext4 defaults 0 1\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$efi_UUID /boot/efi vfat defaults 0 2\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$swap_UUID swap swap defaults 0 0\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"tmpfs /tmp tmpfs defaults 0 0\" | tee -a $FSTAB_FILE"
}


bastardfstabsda() {
    $installcommand "rm /etc/fstab"
    root_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda3 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
efi_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda1 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")
swap_UUID=$(chroot /mnt /bin/sh -c "blkid /dev/sda2 | awk -F 'UUID=\"' '{print \$2}' | awk -F '\"' '{print \"UUID=\" \$1}'")

    $installcommand "touch $FSTAB_FILE"
    $installcommand "echo \"$root_UUID / ext4 defaults 0 1\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$efi_UUID /boot/efi vfat defaults 0 2\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"$swap_UUID swap swap defaults 0 0\" | tee -a $FSTAB_FILE"
    $installcommand "echo \"tmpfs /tmp tmpfs defaults 0 0\" | tee -a $FSTAB_FILE"
}





if [ "$output" == "sda" ]; then
   forsda
elif [ "$output" == "nvme" ]; then
    fornvme
else
    echo "nuh uh"
fi

