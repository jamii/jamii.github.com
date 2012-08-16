---
layout: post
title: "Tunneling in china"
date: 2011-02-07 06:16
comments: true
categories:
---

In Shanghai I found that ssh was blocked at the protocol level so even running sshd on port 80 doesn't work. I don't whether this is widespread or whether it was our hotel in particular that was blocking it. Regardless, I found a workaround using httptunnel.

<!--more-->

On a server outside China:

``` bash
sudo apt-get install httptunnel
sudo hts -F localhost:22 80
```

On your client machine:

``` bash
sudo apt-get install httptunnel
sudo htc -F 22 my.server.com:80
```

Now you can use ssh to your hearts content:

``` bash
ssh user@localhost
scp /some/file user@localhost:/some/file
darcs push user@localhost:/some/repo
```
