---
layout: post
title: "Examining scampy"
date: 2010-05-19 06:16
comments: true
categories:
- python
- scampy
---

[Scampy](http://github.com/jamii/scampy) is a bot for engaging 419 scammers in pointless conversation and consuming time that could have been spent on real victims. It was originally intended to be a smart bot. I had visions of data mining conversations and inventing dsl's for chat scripts. This all takes time however, so in order to get up and running quickly the prototype just selects responses at random from a prewritten list. This turns out to be depressingly effective.

<!--more-->

It appears that the average scammer is about as gullible as their targets.  A typical conversation runs like this:

```
Good Day,
 
I am staff. Sgt. Ronnie Reeve, I found your contact particulars in an E-mail address guide they provide us here, as I desperately need an urgent help to do this deal. I am seeking your kind assistance to move the sum of $12m {Twelve Million U.S Dollars only} to you
in  your destination, as far as I can be assured that my share will be safe in your
care until I complete my service here ... etc
```

```
I am very excited to be partnered with you in this business dealing. Please be quick in supplying further details so that we can progress this more faster.
```

```
Dear Sir,
 
Thanks for your kind mail sir. We have suffered so much here in Iraq so I believe nothing can compensate us enough except for the love of God.
 
Saddam Hussein was a very wicked man so God is compensating his children  for what we suffered because of him.
 
... etc
 
Now, I will need the following information below so as to present you as the beneficiary to the security company where I kept the consigment for safety.
Below are the information needed:
 
1.  Your full names
2. Your phone/fax numbers
3. Your current contact address
4. Your age
5. Your occupation.
 
... etc
```

```
Sir, this does not appear to be a reputable transaction and I cannot risk getting involved with things that are illegal.
```

```
There is nothing to be afraid of here, I have worked out every modalities on how to get this done. I am an American who has his reputation at stake here, so for that reason I will not put myself in anything that will bring me trouble.
 
Just follow my instruction and you will see that we shall be happy together.
 
Please once again I promise you there is nothing to put us trouble here.  I am not stupid to have myself in trouble with all the American strict laws.
 
I hope to hear from you as I have instructed.
```

```
Can you tell me whether I should be expecting further contact from you on this matter?
```

```
Dear Sir,
 
I am still waiting for your kind response.
 
Thanks,
 
Ronnie
```

```
Dear
```

This was an early bug. Ronnie doesn't seem to twig though.

```
Dear Sir,
 
I am worried why I have not heard from you? I hope there is no problem, pls free to share your opinion with me on this matter.
 
I hope to hear from you.
 
Ronnie.
```

```
Are you needing my address? Should I send it to you?
```

```
Dear Friend,
 
As I said earlier there nothing to fear here. Please I will need following information from you so that we continue from there.
 
1. Full names
2. contact address
3. phone/fax numbers
4. Maritus status
5. occupation.

I wait for your honest response.
Ronnie.
```

```
Dear
```

And again.

```
Please if you are not interested just let me know and stop playing me. I have told you what to do and you keep asking me irrelivant questions. Pls dont play with me this is not a joke.
 
Ronnie.
```

```
I am thinking that you have the wrong person as this doesnt seem to be intended for me.
```

```
Hello,

I must confess that its amazing the way you treated this opportunity i made available for our mutual benefits just because you are not serious with it.

Do you actaually think this is a kind of joke? I am really baffled at your attitude towards this once in a life time opportunity.

Just thought I should let you know that I still feel we do business together.

Ronnie.
```

```
Can you please explain this more clearly because I am not understanding you. Especially on the first point that you mentioned, I think that you may have written wrongly because it does not seem correct.
```

```
PLEASE JUST SEND ADDRESS OK?
```

```
Are you needing my address? Should I send it to you?
```

I never heard from him again.
