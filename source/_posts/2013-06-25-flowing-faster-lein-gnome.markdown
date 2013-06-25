---
layout: post
title: "Flowing faster: lein-gnome"
date: 2013-06-25 20:27
comments: true
categories: flow
---

After several weeks of banging my head against the empty space where the gnome-shell documentation should be, I've finally revived technomancy's [lein-gnome](https://github.com/jamii/lein-gnome). It can build, package, deploy and reload gnome-shell extensions and includes a hello-world template. I've also added a unified log watcher that hunts down all the various places gnome-shell might choose to put your stack-traces and a cljs repl server that runs inside your extension so you can trial-and-error your way to victory.

<!--more-->

Future plans for a rainy day include:

* Writing a proper nrepl server for cljs so you can `C-x e` directly from emacs (this is non-trivial for projects with crossover code).

* Figure out how dynamic loading of bindings works in gjs so I can support tab-completion

* Clone the Looking Glass picker tool

In the meantime I'm going to start work on [golem](https://github.com/jamii/golem). Until cljs has true nrepl support my hack for live interaction in emacs is the following:

* Save all extension state to disk on `disable`

* Load all extension state from disk on `enable`

* Hook `lein gnome install` into `lein cljsbuild auto`
