---
layout: post
title: 'Notes on ''Radical Technologies: The Design of Everyday Life'''
---

<https://smile.amazon.com/dp/B01GYPMK5W>

__Examining technologies and their potential impact on society. [Author](https://en.wikipedia.org/wiki/Adam_Greenfield#Publications)'s background is mostly urban design.__

__Goal seems to be:__

> ...people with left politics of any stripe absolutely cannot allow their eyes to glaze over when the topic of conversation turns to technology, or in any way cede this terrain to its existing inhabitants, for to do so is to surrender the commanding heights of the contemporary situation. It’s absolutely vital, now, for all of us who think of ourselves as in any way progressive or belonging to the left current to understand just what the emerging technics of everyday life propose, how they work, and what they are capable of.

__Result is weird mix of insightful, balanced criticism whose potential audience is limited by a liberal coating of disdain eg__

> Not for nothing is there a very significant degree of overlap between the Quantified Self and the “lifehacking” subculture— the same people who brought you Soylent, the flavorless nutrient slurry that is engineered to be a time-and-effort-efficient alternative to actual meals... Here, a not-insignificant percentage of the population has so decisively internalized the values of the market for their labor that the act of resculpting themselves to better meet its needs feels like authentic self-expression.

__Ideas worth considering, but the people who would benefit from considering them are more than likely to be turned off by the one-sided descriptions.__

__But worth reading eg best explanation I've seen yet of cryptocurrencies.__

Smartphones:

* Daily contents of pockets: smartphones are replacing money, access tokens (tickets, smartcards, badges etc), communication, music/radio, watches, photos of family, address books, calendars, notebooks, cameras, maps. Survivors to date are official id, business cards, lip-balm/mints/chewing gum. 
* 'We become reliant on access to the network to accomplish ordinary goals' and 'those who enjoy access to networked services are more capable than those without'
* The network is heterogeneous, unreliable, privately owned, outside of our ability to control/repair
* We forget that presentation of the world (eg maps) are not objective, but mediated by undisclosed private interests (eg what businesses will the map choose to name in the limited available space)
* World is increasingly difficult to navigate without this mediated access eg public transport maps are disappearing from public spaces
* Tracking is enabled by default
* A 'network organ', part of our nervous system, manipulable at a distance by parties unknown and increasingly impractical to disconnect
* __Whether you view the smartphone as net good or bad, it's important to realize the magnitude of this change. We can't afford not to carefully monitor the effects.__

Internet of things:

* Useful to divide by scale - quantified self, smart homes, smart cities
* Quantified self
  * Magnates of the industrial revolution would have faced revolt if they proposed such invasive monitoring, but we are happy to do it to ourselves and hand all the data to private companies
  * Health insurance offering discounts to customers sharing fitness data - amounts to penalizing anyone who doesn't subscribe to whatever pattern of activity the insurance companies deem healthy (__the devices in question are often poor at recognizing activities like climbing or weight-lifting - if your activity of choice isn't running you might be stuck with the higher fees__)
* Smart homes
  * Eg always-on smart assistants
  * '...though the choices these assistants offer us are presented as neutral, they invariably arrive prefiltered through existing assumptions about what is normal, what is valuable, and what is appropriate... [made by] a remarkably homogeneous cohort of young designers and engineers, still more similar to one another psychographically and in terms of their political commitments than they are demographically alike.'
  * Security eg home cameras often open to the web. Likely not a fixable problem - margins at the low end of the market are too slim to afford security, and customers are not skilled enough to obey standard security measures anyway.
* Smart cities
  * Currently sensors for traffic, weather, pollution, systems monitoring for utilities, CCTV
  * Private businesses increasingly monitoring customer behavior eg gaze detection in adverts
  
__[Scientism](http://scattered-thoughts.net/blog/2017/02/23/notes-on-seeing-like-a-state-how-certain-schemes-to-improve-the-human-condition-have-failed/) all over again:__

> We might think of it as an unreconstructed logical positivism, which among other things holds that the world is in principle perfectly knowable, its contents enumerable and their relations capable of being meaningfully encoded in the state of a technical system, without bias or distortion. As applied to the affairs of cities, this is effectively an argument that there is one and only one universal and transcendently correct solution to each identified individual or collective human need; that this solution can be arrived at algorithmically, via the operations of a technical system furnished with the proper inputs; and that this solution is something which can be encoded in public policy, again without distortion. (Left unstated, but strongly implicit, is the presumption that whatever policies are arrived at in this way will be applied transparently, dispassionately and in a manner free from politics.). Every single aspect of this argument is problematic.

> Quite simply, we need to understand that the authorship of an algorithm intended to guide the distribution of civic resources is itself an inherently political act. And at least as things stand today, nowhere in the extant smart-city literature is there any suggestion that either algorithms or their designers would be subject to the ordinary processes of democratic accountability.

__Think about how well credit reports work today, and imagine that expanding to every piece of data that we give up.__

Augmented reality:

* Current AR is clumsy because it takes over the phones function and because it doesn't mesh well with the form factor (tired arms). Main value of AR is immediacy - will need to be always(ish) on. 
* Steve Mann can no longer function without his AR rig, but at least he owns it. If we are becoming cyborgs, we need to think carefully about where our consciousness resides and who owns and controls it. 
* [Continuous partial attention](https://en.wikipedia.org/wiki/Continuous_partial_attention) - reduces available human-human bandwidth

> 'What happens when the information necessary to comprehend and operate an environment is not immanent to that environment, but has become decoupled from it? When signs, directions, notifications, alerts and all the other instructions necessary to the fullest use of the city appear only in an augmentive overlay— and, as will inevitably be the case, that overlay is made available to some but not others?'

Digital fabrication:

* 3D printing was originally idealistic movement - self-replicating manufacturing devices. Convenience won out. Now dominated by commercial offerings.
* Ignores reality of material science - most useful things are made from variety of complex materials. Unlikely that single makerspace could reach more than the basics with any of the technology currently in sight.
* __All that aside, making your own eg furniture is well within the reach of the average person and the materials/tools available at most workshops, and yet there has been no DIY furniture revolution. Don't see why newer tools should be different.__
* Sustainability also a concern.

Cryptocurrency:

* 'This is the first information technology I’ve encountered in my adult life that’s just fundamentally difficult for otherwise intelligent and highly capable people to comprehend.'
* Fundamental trust problem in digital economy - who owns the ledger? Aside from political issues, ledger-keepers are a large source of overhead in all financial transactions.
* Bitcoin:
  * Each bitcoin and each user has a unique signature
  * Transaction identifies the coin, sender and receiver
  * Each node serializes all submitted transactions, checks that they are valid and groups them into blocks (every 10 minutes)
  * Each node competes to be the first to do the computational proof-of-work (mining) to confirm the block and add it to the blockchain (of nested hashes of all blocks back to genesis). Winner gets a bounty.
  * Consensus algorithm - each miner works on the longest chain it knows of. Since every other miner also does that, it's the stable winning strategy.
  * To influence the ledger, an attacker must win the races. Can calculate odds as a function of how much of the network is controlled by the attacker and how far back is the block they are trying to influence.
  * For high-value transactions with untrusted agents, sensible to wait until it is several blocks deep.
  * Proof-of-work and bounty size are continuously calibrated to size of the bitcoin network.
* Bitcoin problems:
  * High latency - 10 mins for low-value, up to an hour for high-value
  * Current transaction rate capped at 1/3000 of current financial system
  * Maximum transaction rate is limited by available energy
  * Two Chinese mining pools control 51% of mining power between them - could co
* Ethereum:
  * Distributed publicly-verifiable computing, paid for in cryptocurrency
  * Smart contracts, autonomous corporations
  * eg kickstarter is implementable as an ethereum contract
* Ethereum problems:
  * Relies on interface to outside world for verification and enforcement of everything except ether. (__Seems surmountable by appealing to various trusted 3rd parties ie doesn't remove the problem of trust, but does decompose it__)
  * Hard-forked to resolve exploitation of a loophole in a contract
* Slock.it
  * Networked locks - connecting blockchain to the physical worldllude to alter the ledger
* Core concept of bitcoin, a shared ledger without trust, has many uses outside of money. Coordination problems abound, and we have a new tool for attacking them with. 
* New forms of coordination are powerful eg joint-stock companies were the building block for the corporation states like the Dutch East India Company, and structure much of the modern world.
* Unclear how these new forms of coordination interact with the law re enforcement and liability - goal is to evade being limited by the law, but there seems to be little attention to alternate solutions to the problems that the law was created in response to.
* __Apparently enough interest in using DAO to structure leftist groups that the author feels compelled to devoting many pages to pointing out why that's a bad idea - largely revolving around the lack of escape clauses in contracts and the lack of ambiguity in commitment / soft boundaries that are often vital in real-world commons.__
* Interest in corporate and government applications: 

> At this moment in history ... large, complex organizations represent the state of the world via the structured collection, storage and retrieval of data. Another way to say this: that which is operationally true in our world is that set of facts whose truth value is recorded in at least one database belonging to a party with the ability to set the parameters of a situation. And most irritatingly, each one of the organizations we truck with over the course of our lives maintains its own database, and therefore, quite literally, its own version of the world.

Automation:

* Worrying concentration of power - robots don't rebel or refuse orders. __Been pointed out elsewhere that the current power-of-the-masses is a historical anomaly. Considering eg [peasant revolts vs artillery](https://en.wikipedia.org/wiki/Battle_of_Frankenhausen#The_Day_of_Battle), it's clear that technology can determine whether oppressive rule can be resisted at all.__
* Humans 'below the api' eg earpieces in Amazon warehouses that instruct second by second movements of employees. 
* Monitoring and automatic evaluation of employees.
* Cognitive agents as front-line staff.
* __See the oddly prescient [Manna](http://marshallbrain.com/manna1.htm).__

> In the end, the greatest threat of overtransparency may be that it erodes the effectiveness of something that has historically furnished an effective brake on power: the permanent possibility that an enraged populace might take to the streets in pursuit of justice.

Machine learning:

* Math-washing, bias, over-fitting
* Unrealistically homogeneous training data
* Accountability is difficult, especially when algorithms are proprietary secrets (__eg [predicting reoffenders](https://www.technologyreview.com/s/607955/inspecting-algorithms-for-bias/)__)
* Abstractions are not neutral (__eg means-adjusted subsidies require defining wealth, which is as much a matter of political values as of data__)
* Boundaries of knowledge/privacy are an important component of society, not clear what happens when we move them (eg FindFace resulted in trolls outing sex workers on public transport)
* Credit scores make a perfect example - no idea if the algorithm is based on correct data, no idea if it bases decisions on protected classes, no accountability for mistakes, no recourse for correcting the record, no idea whether the score is even remotely accurate at predicting financial reliability. And yet half of US companies admit using credit scores to filter hires. (__The insistence of UK credit agencies that I a) don't exist and b) haven't made payments on the mortgage I don't have does not fill me with confidence on the last count.__)
* __Current definitions of fairness, discrimination etc only cover a human level of pattern-detection. Not at all clear what it even means to avoid discrimination when with sufficient data everything is correlated with everything else. Need to figure out, as a society, how to make these definitions precise.__
* __Think of this in terms of error functions? Credit scores etc are optimized for profit. But society would prefer to optimize for fairness. We are training the wrong error function!__
* Regulation is insufficient - assuming the person involved even knew a decision was made and who made it, by the time an explanation has been demanded and the record corrected, the damage is already done. We don't seem to be able to control the propagation of false information.

Artificial intelligence: __weak chapter__.

Illustrates several concrete visions of the future, to provide points of comparison.

> In every case the hard, unglamorous, thankless work of building institutions and organizing communities will demand enormous investments of time and effort, and is by no means guaranteed to end in success. But it is far less likely to be subverted by unforeseen dynamics at the point where an emergent and poorly understood technology meets the implacable friction of the everyday.

> ...the power to make change: the concentrated ability to redirect flows of attention and interest, information and investment, and ultimately matter and energy. This is the fundamental aim of all technology, as it is of all politics. Everything else is a sideshow,

__Themes:__

* __Think of existing social, political, legal etc systems as incredibly complex, sophisticated technology built up via millennia of trial-and-error.__
* __Can't route around legacy systems - have to understand them and interface with them.__
* __Attempts to fix problems without understanding the forces that led to them are doomed to failure.__
* __Technologies intended to revolutionize are, overwhelmingly often, captured and controlled by existing concentrations of power.__
