---
layout: post
title: "Dial-a-stranger"
date: 2011-07-10 06:16
comments: true
categories:
- erlang
- dial-a-stranger
---  

[This spawnfest entry](https://github.com/jamii/dial-a-stranger) is inspired by traveling. I love the idea behind sites like chatroulette and omegle but if I had an internet connection I wouldn't be bored enough to use them. I want a version I can use entirely over the phone network to while away the hours spent stuck in airports and train stations.

<!--more-->

I've built a quick proof of concept using twilio. Dial +1 (650) 763-8833 and you will be put on hold. As soon as there are two people on hold they will be linked together into a conference call. 

This isn't a great solution, since you have to sit around and wait for the next person to arrive. Perhaps a better method would be to have users register by SMS and then make outbound calls to both users once a connection is ready.

I also hooked up a chat bot to the SMS api. Eliza is ready and waiting on +1 (650) 763-8782 to listen to your problems and ask vague questions.

I'm not sure where to go with this. I have a vague idea that it could be turned into a game but the details elude me.
