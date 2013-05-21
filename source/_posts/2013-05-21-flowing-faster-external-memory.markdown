---
layout: post
title: "Flowing faster: External memory"
date: 2013-05-21 20:43
comments: true
categories: flow
---

I always want to be a better developer than I am. What work I do that is worthwhile happens in the few hours of flow I manage to achieve every week. A million different things break that flow every day. I suspect that a large part of achieving flow is keeping the current problem in working memory. To improve my chances I can improve my working memory, offload parts of the problem to the computer or prevent context switches. I'm on my own with the first option, but a better development environment can help with the latter two.

<!--more-->

The first thing that I want to fix in this series is offloading memory. There are basically two kinds of questions I regularly deal with:

* How did I solve this problem / build this software / configure this program X months ago?

* What was I trying to remember to change X seconds ago?

I've started using [deft](http://jblevins.org/projects/deft/) to answer both of these. Deft stores notes in a folder full of flat files and adds a simple incremental search buffer to emacs (searching > organising). This means that my notes are simple plain text which I can easily edit, backup, grep or serve on the web.

For long-term memory I create a new note every time I solve a problem or learn something useful. Within emacs M-' brings up the deft window, typing triggers the incremental search and hiting Enter opens the first matching note.

For short-term memory I have a single note called stack. Hitting C-' opens the stack note with the cursor on a new blank line for adding items to the stack. Hitting C-DEL deletes the previous line and C-q closes the stack. Hopefully this is sufficiently low-friction that the extra memory makes up for the context switch.

My config is [here](https://github.com/jamii/emacs-live-packs/blob/master/deft-pack/init.el). I'm considering writing a gnome-shell extension which displays the last line of the stack in the status bar to remind me what I'm supposed to be doing when my mental stack gets rudely dumped. I also want to add the global key bindings to gnome-shell so I don't have to navigate to emacs first.

This is a very simple tool, which is kind of the point. The more stucture and options added to a note-taking tool the more effort it takes to actually use it and the more likely it is that I lose my entire mental stack whilst doing so.
