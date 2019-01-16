---
layout: post
title: The antisocial laptop
---

I've had this laptop for about three years and it's mostly served me well. It really only has one problem - it hates conference calls.

It doesn't mind the rest of the internet. I can watch videos, listen to music and play games with no problems. But as soon as I try to talk to a human being it's game over. The webcam can't be discovered, the connection drops, and if I don't get the hint it might just reboot itself.

It got away with it for a long time because the excuses were so plausible. The linux drivers for the webcam must be flaky. The wifi here is congested. The demo I was giving must have used up all my RAM and the OOM killer must have taken out something important.

But recently I backed it into a corner and things started getting serious. I ran an ethernet cable through my house and dug up the ethernet-usb adapter that shipped with my laptop. No more excuses.

It responded by not only disconnecting the call I was on, but disconnecting the ethernet. On the next reboot, my monitor stopped updating. On the next, it not only disconnected the ethernet but claimed I no longer had a wifi interface either.

```
jamie@machine:~$ ifconfig

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 238  bytes 24527 (23.9 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 238  bytes 24527 (23.9 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

I found I could pretty reliably cause all three problems at any time by connecting the ethernet cable. But only during conference calls - I spent an entire day working and listening to music via the ethernet without a single laptop tantrum.

I finally figured out what was going on almost by accident. I suspected that the dell ethernet-usb adapter might be the source of the recent problems, and while searching for those keywords I stumbled across a [post from the manufacturers of a usb docking station](https://plugable.com/2016/06/30/investigating-usb-c-problems-on-some-dell-xps-and-precision-laptops/) about customers with similar symptoms that only manifest on this particular laptop. Dell responded with a firmware update that reduced the wifi output power.

It turns out that the usb, hdmi and wifi are all sitting on top of each other and are not sufficiently well shielded. Some experimenting at home confirmed that:

* plugging in my usb webcam increases the number of dropped packets on the wifi
* plugging in the ethernet only causes screen freezes when using an external hdmi monitor
* the ethernet, monitor and webcam play fine together if the wifi is disabled

As satisfying as it is to finally be able to get to the end of a meeting without rebooting, it's also really interesting that for years I've had all the information necessary to debug this but I wasn't able to make the connection. My mental model of causality was limited to the design of the machine and was completely missing the possibility of non-intentional interactions via the physical world. I suspect someone with an EE background would have immediately realized what was going on.
