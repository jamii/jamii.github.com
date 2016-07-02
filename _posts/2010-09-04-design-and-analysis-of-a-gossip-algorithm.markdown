---
layout: post
title: "Design and analysis of a gossip algorithm"
date: 2010-09-04 06:16
redirect_from: one/1283/644001/538941
---

My MSc dissertation 'Design and Analysis of a Gossip Algorithm', in which I present an algorithm for forming a dynamic, unstructured overlay in which each node can generate a stream of independent, uniformly distributed samples of the overlay membership. Such peer sampling services form the basis for a number of gossip algorithms implementing distributed search/recommendation, database replication, reputation management etc. As far as I am aware this is the first peer sampling service which provides any guarantees on the distribution of samples. The mathematical analysis is backed up by model checking in [PRISM](http://www.prismmodelchecker.org/) and test results for the reference implementation.

[PDF](https://github.com/jamii/dissertation/raw/master/writeup/main.pdf)

[Source](https://github.com/jamii/dissertation)
