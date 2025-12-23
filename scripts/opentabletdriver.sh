#!/bin/bash

# install
yay -S --noconfirm --needed opentabletdriver

# Regenerate initramfs
sudo mkinitcpio -P

# Unload kernel modules
sudo rmmod wacom hid_uclogic


# enable systemd service
systemctl --user enable opentabletdriver.service --now
