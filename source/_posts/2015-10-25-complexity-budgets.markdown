---
layout: post
title: "Complexity budgets"
date: 2015-10-25 16:46
comments: true
categories:
---

I notice a tendency to make individual engineering decisions by maximising 'goodness'. Patch X makes the code more complex, but it adds a new feature or increases performance or makes debugging easier. We add up the goodness points, subtract the badness points and if the result is more than zero it's a good patch.

Unfortunately, complexity does not add up linearly. The total cost of a set of features is not just the sum of the cost of each feature. Complexity limits how much of the system can fit into the heads of the developers, and in doing so breeds more complexity. Every time you are forced to do something ugly in one place because of existing ugliness in another place you are feeling this cost.

Worse, there are cliffs in the cost. As soon as a particular subsystem cannot fit into the head of a single developer there are huge additional overheads for communication. Opportunities for improvements or simplification are missed because no one person can see all the parts of the problem. N engineers working on a system that they all understand will crush N engineers working on a system that they each understand part of.

Modularity, indirection and abstraction are not panaceas for this problem. In most cases they reduce local complexity at the cost of global complexity. This is a decision that should be consciously weighed in each case rather than assumed to be an unquestionable win. The failure mode here is huge codebases where every component is so simple that it barely does anything at all, and the process of just finding and piecing together the actual logic consumes all available mental resources.

For any given team, there is a point past which they can no longer collectively understand the system. This creates opportunity costs - spending complexity in one place means you cannot spend it elsewhere. Any new change must have it's benefits weighed against the precious cognitive limits of the team. Try to spend you limited complexity budget in places that give [good value for money](http://permalink.gmane.org/gmane.culture.people.kragen.thinking/202).

This is hard to do well, because complexity has so many ways to sneak in without being noticed. The trick is to carefully separate out [essential complexity](http://shaffner.us/cs/papers/tarpit.pdf) from the morass of assumptions, routines and path dependencies that make up our habitual solution space. Look at the information that must go into the system and the information that must come out. Figure out how fast that needs to happen and find out what your hardware is capable of. Don't start coming up with solutions until you have actually [thought about the problem](http://lesswrong.com/lw/ka/hold_off_on_proposing_solutions/).

After careful consideration you may well end up with a traditional solution and that's fine. But if the first thing you do when given a problem is to pull out your favourite solution then you are throwing away your budget without a fight.
