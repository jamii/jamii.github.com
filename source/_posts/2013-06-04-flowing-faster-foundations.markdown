---
layout: post
title: "Flowing faster: foundations"
date: 2013-06-04 18:02
comments: true
categories: flow
---

I've spent the last few years using Gnome 2 and [xmonad](http://xmonad.org/) on Ubuntu. Since both Ubuntu and the Gnome foundation have dropped support for Gnome 2 I'm going to be forced to upgrade sooner or later. Fortunately I have a two week holiday followed by a new desktop at my new job, so now is a good time to break things on my laptop.

<!--more-->

# Choices

Almost all of my work happens in bash, emacs, firefox and xmonad. What these have in common, to various extents, is what Mr Yegge likes to call [living software](http://steve-yegge.blogspot.com/2007/01/pinocchio-problem.html). This breaks down the interaction barrier and allows them to grow beyond point-and-grunt into an extension of my mind. This is what I look for in any system I'm going to spend lots of time with.

[Unity](http://unity.ubuntu.com/) has the [HUD](https://wiki.ubuntu.com/Unity/HUD) which is basically a CLI for individual applications. There is plugin support [via Compiz](http://wiki.compiz.org/Plugins‎) but nobody seems to be writing any. It's also incredibly closely tied to Ubuntu and despite all the good they have done some of their recent decisions have been worrying. Individually, they are each sensible and justified but taken as a whole they make me a little nervous about investing heavily in Unity. It's a shame, because I would love to use the [Ubuntu phone](http://www.ubuntu.com/phone).

[Gnome Shell](https://live.gnome.org/GnomeShell) is largely written in js and is on its way to building a [healthy ecosystem of extensions](https://extensions.gnome.org/) (or will be, if it stops breaking them every version bump). It even has an [almost-functional repl](https://live.gnome.org/GnomeShell/LookingGlass) which surely can be shoe-horned into running [cljs](https://github.com/clojure/clojurescript). It's missing the HUD but most of the applications I use have their own CLI anyway. As proof of its flexibility, it has acquired not one but three tiling window managers: [shelltile](https://extensions.gnome.org/extension/657/shelltile/), [shellshape](https://extensions.gnome.org/extension/294/shellshape/) and [gtile](https://extensions.gnome.org/extension/28/gtile/). Of course, all them were broken by the 3.8 update...

[KDE](http://www.kde.org/) has [plasma](http://www.kde.org/workspaces/plasmadesktop/), which it uses for ... uh ... desktop widgets. It also has [activities](http://userbase.kde.org/Plasma#Activities) which are almost a fantastic idea but it uses them to manage ... desktop widgets. I don't remember the last time I saw my desktop. If I'm being unfair to KDE it stems from frustration - they were way ahead of the game on customisation and inter-application communication and they don't seem to have done anything *useful* with it.

There are also a million minimalist desktop environments but I prefer to have most of my work done for me, so long as I have the power to monkey-patch anything I disagree with. Vertical integration can be a beautiful thing when it works.

So it looks like Gnome Shell wins. People complain that it is unusable without extensions. For my purposes that is irrelevant. Most of my favourite software is unusable without customisation (especially emacs). What is important is the potential for sculpting it into something better.

# Experience

The [Gnome Tweak Tool](https://live.gnome.org/GnomeTweakTool) is absolutely essential. I have a few other extensions installed so far but none are particularly essential. There are a few more I will have to write myself.

I expected to find [Gnome Do](http://cooperteam.net/) indispensable. I can't quite puy my finger on the reason but I instead found it intensely annoying and quickly uninstalled it. I think it's an uncanny valley thing - it's *almost* a real repl. Adding panels to the [Overview](http://media.bestofmicro.com/fedora-linux-gnome,M-M-329998-13.png) might be a better option for me.

Most of my setup time was burned on remapping keys. Gnome doesn't run .xprofile or .Xmodmaprc and adding them to gnome-session doesn't persist the changes across suspend/hibernate. I spent a while trying to remap keys [at the kernel level](https://wiki.archlinux.org/index.php/Map_scancodes_to_keycodes) before eventually realising that Gnome Tweak Tool has a keyboard section. It doesn't have all the options I want but it does mean I can crib from their remapping code later.

Similarly, Gnome overrides the xorg.conf touchpad settings and its settings dialog doesn't provide an vertical-edge-scroll option. Fortunately the setting still exists and can be set with dconf-editor under `org/gnome/settings-daemon/touchpad`. Again, I'm leaning towards configuring this in js in the future to keep all my changes in the same place.

So far I'm impressed at the potential of Gnome Shell, if not the default reality. The overview completion is fast and accurate. The notification system is a big improvement over Gnome 2 (especially the on/off toggle). The animations are smooth even on my integrated graphics. The ui and icons are simple and clear. With the dark theme enabled the shell is beautiful without getting in the way. Beauty is important in anything I spend half my life staring at.

# Bonus

I also took the oppurtunuity to switch from [Ubuntu](https://www.archlinux.org/) to [Arch](https://www.archlinux.org/). Partly because of the nervousness I mentioned earlier, but also because Ubuntu keeps fucking overwriting my config files. I've given up touching anything beneath the surface because every Ubuntu upgrade breaks everything. Arch seems to be more kindly inclined towards tinkering and customisation and the wiki is a fantastic resource for learning about linux internals. It has a reputation for being unstable but since my new job will be developing in Windows on a fancy desktop the risk of breakage on my laptop isn't a big deal. And it doesn't overwrite my config files without asking.

The installation was straight-forward apart from a [known mistake](https://bbs.archlinux.org/viewtopic.php?id=162725) in this months iso. My hardware all worked without any configuration. Suspend and hibernate are faster and more reliable than they were in Ubuntu. My battery life is slightly better. [Pacmatic](http://kmkeen.com/pacmatic/) somewhat alleviates the fear of breakage. Installing proprietary software (skype, spotify) has not been a problem. I did have to [tweak the fonts](https://wiki.archlinux.org/index.php/Font_Configuration#Infinality:_the_easy_way) and I have still have some missing unicode characters in firefox which I haven't yet looked into.

# Next

The next part of this series (which is due at some undetermined point in the future) will probably be writing a hello-world style extension in [cljs](https://github.com/clojure/clojurescript) as the first step towards a document-centric tiling window manager.
