---
layout: post
title: "Notes on 'A Small Matter of Programming: Perspectives on End User Computing'"
date: 2016-06-17 17:00
comments: true
categories: 
---

https://smile.amazon.com/dp/B00BJGM0NE/

__Published in 1993, but sadly the field has not changed dramatically since then.__

> ...no matter how much designers and programmers try to anticipate and provide for what users will need, the effort always falls short because it is impossible to know in advance what may be needed.

End-users have the motivation and domain-knowledge to create/customize/specialize applications. In certain domains - spreadsheets, statistical computing, CAD - this is incredibly common. What do those environments do differently?

Book explores:

* Task-specific programming languages
* Visual application frameworks
* Collaborative work practices

### Introduction

Visions of the future: computer-as-agent vs computer-as-tool. In former vision, sophisticated programs allow the user to interact with the computer like another human ("plot a course to...") and the computer is doing all the interesting work. In the latter, the computer is an extension of the users will that enables new kinds of thinking. 

Where are the productivity improvements from the computing revolution? Possibly still bottlenecked by the tiny number of programmers.

Author was involved in [ethnographic studies](https://scholar.google.co.uk/citations?hl=en&user=hwc6A1MAAAAJ&view_op=list_works&sortby=pubdate) of spreadsheet and CAD users in the early 90s. 

> We begin by asking why we need end user programming systems at all. Aren't natural language -based systems that will allow us to just tell the computer what we want right around the corner? __Written in 1993 :)__

Will argue against conversational interfaces, in favour of task-specific formalisms.

### Conversation and computers 

> ...in natural language systems, "users must learn not the interface language itself, from scratch, but rather the boundaries that within a language they already know and that divide the recognizable sublanguage from the rest of the natural language"

__In other words, natural language interfaces tend towards an uncanny valley. If they don't have a near-human level of comprehension, the similarity to human language is misleading instead of helpful. The user has no easy way to know what kinds of phrases will lead to the desired results.__

Natural language is disambiguated by knowledge of the world and by shared context, both of which computers are so far lacking.

__An further objection that I rarely see mentioned is one that should be familiar to anyone who has tried to extract a specification from a client - human languages are not well suited to precise descriptions of complex systems. This is the reason why we have mathematics, and why mathemeticians have their own weird pseudo-English.__

Why insist on language as the only natural interface?

> "[Driving a car] is not achieved by having the car communicate like a person, but by providing the right coupling between the driver and the action in the relevant domain.

Similarly for eg playing musical instruments and reading music. __As Andy Clark [notes](http://scattered-thoughts.net/blog/2016/05/19/notes-on-natural-born-cyborgs-minds/), the ability to extend our capabilities by mastering a wide variety of new interfaces is one of the features that distinguishes humans from other animals. In this light, the popular insistence that non-conversational interaces are unnatural is bizaare.__

> [Informal, mundane conversation provides] the "point of departure for more specialized communicative contexts... which may be analyzed as embodying systematic variations from conversational procedures."

__ie we have many specialized dialects that we use for different kinds of tasks. The focus on mundane conversation as universal interface is therefore misguided.__

Examples: [Atkinson 1982](http://www.jstor.org/stable/828155?seq=1#page_scan_tab_contents) - compared to mundane conversation, communication in court has different rules for who may speak and on what subject. [Holstein 1988](http://socpro.oxfordjournals.org/content/35/4/458.abstract) - in commitment hearings "the types of questions, the length of pauses, the extent to which patients are interrupted during testimony, and whether conversational indicators of interest were used depended on whether the patient was being questioned by a public defender or a district attorney" - in other words, the fine details of how the patient spoke was highly influenced by the goals of the person interviewing them. 

So even a natural language -speaking interface would have to be tailored to different tasks via different dialects. Wouldn't be universal, which means we still have the problem of choosing and teaching the interface. Natural language doesn't make interfaces go away.

In some cases ambiguity itself has a deliberate purporse __eg flirting__.

Understanding in human conversations sometimes fails, and there are backup protocols for corrections which themselves can fail. __"No, I said 'what did you say'".__ Conversations do not guarantee understanding.

Many professions develop their own formal dialects or languages for dealing with the lack of precision in natural languages. People may have trouble learning specific formalisms, such as the current crop of programming languages, but that doesn't mean that formal languages in general are inherently difficult. (Examples later of surprising uses of formal languages).

Formal languages are sometimes graphical, when the situation calls for it. __Eg diagrams are preferred for describing electronic circuits.__

__Also note that some formal languages are near-unspeakable - eg most mathematical proofs are difficult to convey accurately without writing.__

Time to stop thinking of natural language as *the* intuitive interface, and start thinking about what modalities the task demands. 

### Task-specific programming languages

New Guinea tribes use [a language of drum signals](http://www.pngbuai.com/600technology/information/waigani/drums/WS97-sec7-Norman2.html) to communicate over long distances. Conductors use special signals to direct orchestras. [Crochet patterns](http://www.craftyarncouncil.com/tip_crochet.html) and [knitting patterns](http://www.craftyarncouncil.com/tip_knit.html) sometimes contain modular functions. Popular sports have huge rulebooks containing complicated state machines. [Baseball scorecoards](http://mlb.mlb.com/mlb/official_info/baseball_basics/keeping_score.jsp). Musical notation. Sign language. Morse code. Alphabets. Numerals. Arithmetic. Algebra. 

Formal systems and languages are ubiquitous. Humans are skilled at making, learning and using them. So why the struggle with programming languages?

Key to learning is interest/usefulness and domain familiarity. Programming languages spurn both, forcing users to learn an overwhelming array of non-task-specific trivia before being able to accomplish their goal. __Eg how to decompose problems into a single sequential control flow, how different data-structures behave in response to the same method calls, how to mentally simulate a region of code to track down errors.__ The level of abstraction at which the language operates is the same regardless of domain. Accountants, biologists, musicians may all be using different high-level libraries but all of them have to also be conversant in the language of arrays and instruction pointers. 

Spreadsheets, statistical packages and CAD editors are task-specific - the user overwhelmingly only deals with details at the level of the problem they are trying to solve. The spreadsheet user doesn't have to specify how cells are kept up to date, or what order expressions are executed in. The CAD user doesn't have to know what data-structures are used to store the schematic, or how they are arranged in memory.

Instead, they work with familiar primitives in a domain they directly care about.

> [In programming languages] it is hard to see what combination of low-level primitives will produce the correct task-related behavior. 

__Picture the CAD user given a traditional programming language and trying to figure out how to translate their concepts of parts and shapes into bits and pointers. It's not that they inherently struggle with formal systems, it's that the system they are presented with is a long way from the problem domain and the mapping between the two is effortful and frustrating.__

> A mathematician, in a broad sense, already knows Mathematica.

Let's focus on spreadsheets.

High-level, task-specific programming primitives. Found that most users used fewer than 10 different functions per spreadsheets. Rest of the complexity is in the relationships between cells. Where a traditional language would require knowledge of control flow, scoping, data-structures etc for the same task, the spreadsheet user only needs to understand how to refer to other cells. Similarly, most spreadsheets only use numbers and strings as datatypes. 

From a motivational point of view, the fact that the user can understand everything they need to solve their task in a few hours is crucial to the widespread success of spreadsheets. In programming languages, the basic concepts (eg for loops) are much harder to learn and are often still error prone even for experienced users (eg for loops).

Everything is accessed through the same interface. No need to learn to use the terminal, manage multiple files, import libraries, compile before testing etc. Allows users to concentrate on the task instead of the tool. __It's a [transparent tool](http://scattered-thoughts.net/blog/2016/05/19/notes-on-natural-born-cyborgs-minds/).__

No complex or global control flow constructs. Most spreadsheets only have 'if' and it's limited to acting within a single cell. __Means that the spreadsheet can be understood as a static relationship rather than a dynamically evolving process.__

User only has to specify relationships between cells, not worry about how to keep them up to date.

Collections as adjacent cells, rather than introducing a new concept. Iteration built into functions (sum, average etc) rather than introducing a new concept.

Direct support for copy-and-paste, rather than shaming.

Notes that early spreadsheets were purely textual, had terrible UX, but were still succesful for the same reasons. Visual interfaces are just icing. Besides, formula language is still completely textual and users manage to learn it. None of studied users reported the textual langauge as one of the areas that caused problems, and all of them reported that syntax errors were rare. __The fact that individual formulae are small and separated from each other probably contributes here - syntax errors such as missing braces are very easily localized.__

Building task-specific languages is expensive. Could result in a prolifiration of interfaces. Also hard to gauge just how specific to make them. __Many programmers seem to be in favour of embedding domain specific languages to solve these problems, but in my personal experience the details of the lower-level langauge tend to leak through.__

Consistency across eg applications in an office suite is a well-studied problem already, and can provide some guidance for future task-specific systems. 

Emacs Lisp fits the few-task-specific-primitives point (buffers, marks etc) but is not successful with end users because it's also necessary to learn the underlying lisp to do *anything* interesting.

HyperTalk makes the wrong compromise - it's a friendlier syntax but still has most of the underlying complexity of a traditional language, just without the power or performance.

How to study task domains? [Activity theory](https://en.wikipedia.org/wiki/Activity_theory). [Distributed cognition](https://en.wikipedia.org/wiki/Distributed_cognition). 

> Distributed cognition is concerned with structure - representations inside and outside the head - and the transformations these structures undergo. This is very much in line with traditional cognitive science but with the radical difference that access to external resources - other people and artifacts - is taken to be a crucial aspect of cognition.

Notes in passing that formal languages are more cross-culturally shareable than natural language interfaces.

### Interaction techniques for end user application development 

Arguing that interaction design cannot fix the problem alone - it's semantic design that is crucial ie can't just slap boxes and arrows over the top of the same old for loops and arrays and expect users to suddenly find it easy.

Visual languages. Often claimed to be more natural, avoid the need to learn syntax and to reveal semantics through obvious pictorial connotations. 

Pretty much every programming paradigm claims to be natural and it's not clear what kind of evidence would even support that claim, and some empirical studies with specific languages found that users were more succesful with the textual versions. 

While shapes can suggest syntax (eg [Scratch](https://scratch.mit.edu/)) so can structural text editors. 

Much empirical research demonstrates that understanding the meaning of picture, images and icons is heavily experience and culture -dependent. 

In authors study users strongly prefered to see as much data on a single screen as possible. Visual/pictorial representations are usually less dense, and tend towards clutter in complex programs.

While there is some research on the subject, it's still far from clear for which domains visual representations are better, and they are certainly not a panacea for end-user programming in general.

Forms-based systems - have the user fill out from a fixed list of options. Lacks generality, but where applicable they reduce memory load and are highly discoverable. __I notice some systems try to be user-friendly by enumerating every possible option in a huge form (eg [IFTTT](https://ifttt.com/)). The result is an overwhelming barrage of options, and very low density of information. Trying to modify a complex list of IFTTT rules is incredibly frustrating as you bounce back and forth between forms.__

Programming by example modification. Not clear how to find an appropriate example. Understanding programs is still hard, even if they are written for you. Doesn't solve the problem of not knowing how to compose low-level primitives to get the desired effect.

Programming by example - specify example inputs and outputs and have a program synthesised to match. If the system doesn't produce the desired program, there is no recourse. If the user can't read the resulting program, they can't be sure whether it correctly generalised their examples. Hard to express boundaries, termination and branching with examples. __Works well in some restricted domains though, eg [Trifacta](https://www.trifacta.com/). Seems useful as a discovery mechanism too - perform a simple action to discover the corresponding code, as a starting point for editing.__

Programming by specification. An executable specification is a programming language. The distinction between the two seems arbitrary. 

> ...it is clear that the users are not readily able to generate requirements that strictly fit the constraints presented to them.

### Visual application frameworks

Advocates for combining textual and visual systems to match the strength of each.

Spreadsheets combine text and graphics. Relationships between cells are displayed both using alphanumeric codes and coloured highlights. Selections can be made by typing or pointing. Formulae are expressed in a compact textual language, while the resulting data is organized spatially. No need to specify names for cells - meaning is implicit in layout.

Spreadsheets are difficult to debug because code is hidden away and often repeated with minor changes. Cell dependencies are invisible, revealed only for the single, selected cell. 

Reuse is difficult because there are no natural modularity boundaries.

Similar to fine-grained OO programs. Local modularity (cells or objects) is very powerful but makes it hard to get a global overview of the relationships. Similar problems in HyperCard where scripts are attached to screen objects. __I am having the exact same problem in Unity, where code has to be in a component attached to an entity.__

> ...the overall visibility of the program has been reduced, eg you can' easily see the scripts for two buttons at the same time...

In Logo, programs are textual but the results are displayed visually by animating the turtle. Users can manually execute and experiment with commands until they get the desired result, then paste the snippet into a larger program.

Parametric design in CAD programs. Uses textual constraints to specify a family of drawings. Has similar problems with vizualizing dependencies between constraints. __[Auto Layout](http://www.appcoda.com/introduction-auto-layout/) is similar. Anecdotally, I've heard similar complaints - that it can be hard to predict or understand the interaction between constraints. Apple don't appear to have made any attempt to visualize the dependencies.__

Other visual formalisms exist, like charts, sparklines, pivot tables etc.

### Collaborative work processes 

Authors studies show end-user programs created together by groups of people with a wide variety of training. Rarely a solo endeavour.

__Programming languages are terrible for this. My typical example is two people working together at a hackathon. If they were collaborating on, say, google sheets, all they would have to do is share a url and they would get collaborative editing with live execution and shared version control. Instead, the process looks more like 'git push, poke, git pull, merge, recompile, restart'. Embarassing.__

'Local developers' - domain experts who are more inclined to tinker and fiddle, and as a result tend to be the local goto for questions. Wrt spreadsheets, these users are often the source of macros and basic scripts which disseminate through the company.

Designing for users of different levels to collaborate requires good module boundaries. Should be possible for an advanced user to provide a tool whose use doesn't require the understanding of the advanced features used to create it. Eg separation between formula language and macro language in spreadsheets. __This is an unfortunate example, because that separation really bugs me. By switching the entire language it creates a huge barrier to entry at that point. Better to make it an extension of the formula language than a whole new scary thing to learn. Smooth learning curves are important.__

### Scenarios of end user programming 

Wants to change emphasis from 'non-programmer' who needs to be coddled to 'domain expert' whose strengths need augmenting. Focus on the skills and knowledge of the target user and figure out how to make them even better at their work.

## Thoughts

__I first read this a few years ago. The importance of matching semantics to the task, and of avoiding unnecessary details, was already dimly in my mind after reading texts such as [Out of the Tarpit](http://shaffner.us/cs/papers/tarpit.pdf). The idea that global control flow is harmful was new to me though, and gradually grew on me over the last few years of research. I've noticed more and more problems that seem to come down to the ubiquity of incidental time.__

__Equally relevatory at the time were the numerous examples of formal languages in widespread use. The idea that syntax is the main obstacle to programming completely pervades the programming community, but in this light it's clearly bunk. People commonly master languages with much crazier syntax (I'm currently learning German, and have to keep reassuring myself that if five year olds can do this so can I).__

__Later reading in cybernetics cemented in my head the idea that mastering novel interfaces is a fundamentally human activity. It's a bizaare accident that we view certain examples (mathematics, programming) as somehow unnatural, or that we hold up conversation as *the* natural interface when in many circumstances it's not even the interface of choice between humans.__

__I would like to learn a lot more about what makes particular languages/interfaces easy, powerful, transparent etc. Reading suggestions are [very welcome](mailto:jamie@scattered-thoughts.net).__
