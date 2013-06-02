---
layout: post
title: "Flowing faster: saving the cloud"
date: 2013-06-02 03:36
comments: true
categories: flow
---

While we're on the subject of backups - like most people, I rely pretty heavily on cloud services. It sort of snuck up on me. I'm generally trying to move towards using cloud services as dumb servers so I can easily replace them. The first step is to be able to export and backup all my data.

<!--more-->

I considered using The Locker Project for backing up cloud services, but it appears that Singly have pivoted from ['control your own data'](http://lockerproject.org/) to ['give all your data to us'](https://singly.com/product/). Back to the drawing board...

I use [OPML Support](https://addons.mozilla.org/en-US/firefox/addon/opml-support/) and [Brief](https://addons.mozilla.org/en-us/firefox/addon/brief/) to replace google reader and [Evolution](http://projects.gnome.org/evolution/) to back up google mail, calendar and contacts. My address is on my own domain and managed by google apps. I don't yet use a local mail reader but Evolution looks like a reasonable fallback if I have to drop gmail.

For music I use [Tomahawk](http://www.tomahawk-player.org/) with a [Spotify Premium](https://www.spotify.com/) account as the main resolver. I create playlists in Tomahawk using both the chart apis and the [Echo Nest](http://echonest.com/) api and sync them to Spotify to download to my phone. There's still a little too much manual button pressing in that process but it's much easier than managing my own collection. Both Tomahawk and Spotify mobile scrobble to my last.fm account which I backup with [lastexport](https://gitorious.org/fmthings/lasttolibre/blobs/master/lastexport.py).

Facebook is really the only service I couldn't replace, due to a combination of network effects and poor export tools. I use the builtin export service but unfortunately it seems to be pretty hard to automate. The only non-proprietary solution I could find was [ArchiveFacebook](https://addons.mozilla.org/en-us/firefox/addon/archivefacebook/) which I suppose could be run from the command line somehow. For now I just set a monthly reminder in my calendar.

So now I have all my cloud data synced on my machine where the backup tools from my last post can take care of it.
