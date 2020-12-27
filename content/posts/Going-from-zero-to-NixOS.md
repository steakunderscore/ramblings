---
title: "Going From Zero to NixOS"
date: 2020-12-27T11:00:21Z
draft: false
disqus: false
---

This is partially a clone of the [NixOS Manual], but with my requirements being met of how I like to set up boot and storage.

The plan/requirements I had:

 - Boot EFI without grub
 - Only boot partition is not encrypted
 - Use [LVM on LUKS] with an encrypted root and swap partitions

Assumptions:

 - Livedisk written to USB drive
 - Booted from live disk using EFI (It's important you didn't boot using grub)

## Setting up partitions

First I set up the primary partitions which reside directly in a gpt partition table. Then I set up LVM on LUKS for root and swap partitions.

### Primary partitions

**Note**: I'm using `/dev/sda`, you might need to use a different device, check `lsblk` to work out which device you want to use.

Create a partition table, or at least ensure I'm using gpt.
```
parted /dev/sda -- mklabel gpt
```

Create boot/EFI/ESP partition and set it up with FAT32
```
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
mkfs.fat -F 32 -n boot /dev/sda1
```

Create LUKS partition for the rest of my encrypted partitions
```
parted /dev/sda -- mkpart cryptroot 512MiB 100%
```

### Setting up LVM on LUKS partitions

Format the disk with the LUKS structure, some of this was lifted from [NixOS's guide]( https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system).

Setup and open the LUKS encrypted partition
```
cryptsetup luksFormat /dev/sda2
cryptsetup open /dev/sda2 cryptlvm
```

Setup our LVM pv and vg
```
pvcreate /dev/mapper/cryptlvm
vgcreate MyVolGroup /dev/mapper/cryptlvm
```

Create an 8GB swap and reaming for mounting as `/`
```
lvcreate -L 8G MyVolGroup -n swap
lvcreate -l 100%FREE MyVolGroup -n root
```

Finally, formatted the root and swap partitions
```
mkfs.ext4 -L nixos /dev/MyVolGroup/root
mkswap -L cryptswap /dev/MyVolGroup/swap
```

## Mounting the new partitions

```
swapon -L cryptswap
mount /dev/disk/by-label/nixos /mnt
mkdir /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

**Note**: If you need to reboot in to the livedisk and fix something, first run `cryptsetup open /dev/sda2 cryptlvm` then the mount commands above.

## NixOS Configure

Now that I've have got all our partitions setup and mounted to `/mnt` lets configure NixOS.

```
nixos-generate-config --root /mnt
```

I had to manually add the crypt init as it's not picked up by default
```
# /etc/nixos/hardware-configuration.nix
{
  # snip...
  boot.initrd.luks.devices."cryptlvm".device = "/dev/disk/by-partlabel/cryptroot";
  # snip...
}
```

One last thing I needed to check was that `systemd-boot` is being used. If not, this is because I didn't boot using EFI to start with. I fixed this either manually fix this or reboot and start again skipping to [mounting](#Mount the new partitions)
```
   # Use the systemd-boot EFI boot loader.
   boot.loader.systemd-boot.enable = true;
   boot.loader.efi.canTouchEfiVariables = true;
```

Now update the main configuration. This I won't document as I am hoping to just pull this from a git repo in the future.
```
vim /mnt/etc/nixos/configuration.nix
```

Now it should be good to reboot!
```
reboot
```

This gets me to having a running system 🎉.

Some more resources that were useful:

 - [NixOS Manual]
 - [LVM on LUKS]
 - [Configuration Collection](https://nixos.wiki/wiki/Configuration_Collection)

[NixOS Manual]: https://nixos.org/manual/nixos/stable/index.html
[LVM on LUKS]: https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
