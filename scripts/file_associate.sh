#!/bin/bash
# This file set file type associations for the system. It is intended to be run after the desktop environment is installed.

# set ark as default application for archive file types
xdg-mime default org.kde.ark.desktop application/zip
xdg-mime default org.kde.ark.desktop application/x-7z-compressed
xdg-mime default org.kde.ark.desktop application/x-rar
xdg-mime default org.kde.ark.desktop application/vnd.rar
xdg-mime default org.kde.ark.desktop application/x-tar
xdg-mime default org.kde.ark.desktop application/gzip
xdg-mime default org.kde.ark.desktop application/x-xz
# set thunar as default application for directory file types
xdg-mime default thunar.desktop inode/directory
