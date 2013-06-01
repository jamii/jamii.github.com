---
layout: post
title: "Flowing faster: backing up"
date: 2013-06-01 02:12
comments: true
categories: flow
---

A lot of the work in this series is going to be about improving my working environment. Let's start with backups, so I don't lose all this hard work.

<!--more-->

I backup my entire filesystem to [tarsnap](http://www.tarsnap.com/) every week. I paid around $70 for the last year of usage. The tarsnap documentation is excellent so I won't go through the setup here, just my usage:

``` bash
set -e
#!/bin/bash
pacman -Qeq > /home/jamie/packages
DATE=`date +%Y.%m.%d-%H.%m.%S`
tarsnap -v -c -f "alien@$DATE" \
    --cachedir /usr/local/tarsnap-cache --keyfile /home/jamie/tarsnap.key \
    --exclude /dev --exclude /proc --exclude /sys --exclude /tmp --exclude /run --exclude /mnt --exclude /media --exclude /lost+found --exclude /swapfile \
    --exclude /home/jamie/.thumbnails --exclude /home/jamie/.mozilla/firefox/*.default/Cache --exclude /home/jamie/.cache/chromium \
    --exclude /var/lib/pacman \
    --exclude /home/jamie/Downloads \
    --exclude /home/jamie/.cache \
    --exclude /home/jamie/music \
    --exclude /home/jamie/.local/share/Trash \
    --exclude /home/jamie/VirtualBox* \
    --exclude /home/jamie/old-home \
    /
```

The first two lines of excludes are fairly standard. The rest come from looking through the output of `sudo du -h -t 100000000 /` for unnecessary folders.

The restore process is pretty simple even for a different machine: install the os, restore /home/jamie, reinstall all packages in /home/jamie/packages, diff the rest of the backup and copy over anything that's not machine-specific.
