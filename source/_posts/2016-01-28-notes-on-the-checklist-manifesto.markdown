---
layout: post
title: "Notes on 'The Checklist Manifesto'"
date: 2016-01-28 14:39
comments: true
categories:
---

http://www.amazon.com/gp/product/B0030V0PEW

Critical tasks are becoming more and more complex, requiring many more subtasks to be completed correctly. A simple checklist can often significantly reduce the error rate of even experienced professionals.

## Chapters

### Introduction

A stab patient in ER almost dies due to massive internal bleeding from his aorta, despite the stab wound being in his stomach. Despite doing almost everything correctly, the ER team almost loses him because nobody remembers to ask what weapon he was stabbed with. A bayonet, not a knife.

A cancer patient's heart stops during surgery. Almost 15 minutes before the anesthesiologist is brought in and recalls that he was given a dose of potassium. High doses can stop the heart, so they fish out the bag and find that the concentration was accidentally 100x too high.

Complexity of medicine has skyrocketed. Doctors and surgeons have many, many more tools and knowledge than before. Often the difficulty is just in correctly applying them. The most experienced, highly-trained experts in the world still make simple errors of omission that cost lives. How can we do better?

### The problem of extreme complexity

Describes the process of reviving a girl who spent half an hour under icy water. Stabilized after two days of work. Went home after two weeks and within a few years made a complete recovery. The entire process is astoundingly complicated and a single mistake, omission or slip of timing would have ruined it all. These cases are rare not because we don't have the technology, but because we don't have the level of perfection it takes to get every single detail right. __I am utterly blown away by the complexity described. I had no idea.__

Rough numbers - 13000 recognized diseases/syndromes/injuries, 6000 drugs, 4000 medical and surgical procedures. That's the toolkit. Despite intense specialization, in one year an average doctor might see 250 different primary conditions, work around 900 other active problems, prescribe 300 different medications, order 100 different lab tests, perform 40 different office procedures. One of the most common diagnoses is 'Other'.

The average ICU patient requires 178 actions per day. Staff error rate is only 1% - still an average of two per day per patient. 4% of lines are infected within 10 days, with a fatality rate of 5-28% depending on initial condition. 4% of urinary catheters lead to bladder infection. 6% of ventilators lead to pneumonia, with a fatality rate of 40-45%. Overall about half of ICU patients develop a serious complication.

So far the answer has been hyper-specialization eg author specializes in removing cancer from endocrine glands.

Deaths following surgeries at 3x rate of traffic deaths. At least half of deaths and major complications were avoidable in theory.

What do you know when expertise is not enough?

### The checklist

Demo flight of the Flying Fortress crashed and exploded due to pilot error. So much more complicated than previous planes that even the experienced test pilot simply missed step. Declared "too much airplane for one man to fly".

Instead of blaming the pilot or requiring more training, Boeing created the first pre-flight checklist. Single index card with step-by-step checks. FF went on to fly 1.8m miles without a single accident.

Medicine is far too complicated to make step-by-step lists for everything. But do check 4 vital signs.

Reasons for failure. Distracted / tired / forget __ie PFC failure__. Skip a step that doesn't seem to matter (complication rates may be low, but if lots of people skip stems they multiply). Checklists instill discipline.

Experiment - 5 stage checklist for putting in lines. Trivial stuff, everyone knows it. Nurses observed that at least one step was skipped in more than a third of patients. Nurses now authorized to stop doctors if they skip a step. Line infection rates went from 11% to 0%. Over a year, estimated this prevented 43 infections, 8 deaths and $2m in costs. Adding further checklists for other simple procedures had similarly dramatic effect.

Not just aid to recall - found that often staff didn't know how important some steps were.

Has to have buy-in from every level eg in one case, found that chlorhexidine soap not always available - requires executives to change ordering.

Similar approach to resuscitating drowning victims. Gave checklist to rescue squads and telephone operators and used them as coordinators, so that when the victim reaches the hospital everything is already prepared.

### The end of the master builder

Construction used to have a 'master builder' who coordinated all work. Modern construction is far too complicated for that to work. __Common in software forums to hear that software is different engineering. "We know how to build a bridge, they're all the same". In the descriptions here I notice that even building a mall involves an extraordinary amount of complex problem-solving. There are too many permutations on building design for it to be a matter of just plugging numbers into a standard design.__

Instead of a master builder, the work is orchestrated by a combination of legal frameworks (building codes) and project-management software. There is a massive dependency graph of tasks which is updated every week and printed out on the wall of the main office. Many of these tasks are actual construction tasks (place flooring, install air ducts etc). Others are communication tasks (eg "contractors, installers and elevator engineers need to meet to review the condition of the cars"). __Tools that require code review before merging branches are a simple form of this. I'm not aware of whether large-scale organizations do the same for other tasks eg require that security engineers sign off on design before deployment.__

Further specialized tools are used to track blueprints, calculate load, check fire safety. Tool called Clash Detective automatically finds conflicts between designs of different subsystems (eg structural beam passing through light fixture), emails the involved parties and schedules a meeting in the task graph.

Safety checks are not strictly laid out in the legal code - too complex. Instead the code dictates that for each sub-domain a qualified professional must sign-off on a list of checks. Dictates the process but leaves room for expert judgment and innovation.

The US experiences an average of 20 serious building failures per year - a 0.00002% error rate.

### The idea

Philosophy is to push power of decision making to the periphery and make management (which is part human, part machine) responsible only for enabling coordination and orchestration. __Note that most modern militaries have also gone through this transformation, pioneered by the Wehrmacht.

During Katrina, FEMA was ineffective. Too centralized, field agents had no power to make decision, central office didn't have timely access to information. Resulted in farces like supply trucks being turned back because they weren't mentioned in the plan, and hundreds of buses sitting idle because noone had the authority to decide what to do with them.

WalMart much more effective. Top level concentrated on setting goals and tracking high-level view, as well as encouraging communication between various parties.

Not about private vs government. Plenty of private corps (electrical, phones, oil) fell over while local police and firefighters coped admirably. Difference is about power and communication.

Story of Van Halen and the brown M&Ms - testing the error rate of the concert staff.

Award-winning restaurant that maintains quality by forcing staff to follow printed recipes. Recipes are adjusted and experimented with over time. __Staff creativity/expertise is applied to the process, not to the individual actions.__ Food is tested on the way out to detect mistakes. Scheduled quick meetings to raise concerns, plan reactions to potential problems.

### The first try

Author worked with WHO to figure out how to improve world-wide surgery rates. 7m per year left disabled and 1m dead after surgical complications.

Huge range of environments from worlds best hospitals to single-doctor operations.

Looked at successful public health interventions. Smallpox vaccination. Tracking cholera to public wells. Common attributes - simple interventions, carefully measured effects, widely transmissible benefits. __This is a fantastic list of think about for future research.__

Distributing leaflet with instructions on how and when to wash hands in Karachi slums reduced diarrhea by 52%, pneumonia 48%, impetigo 35%. People already washed hands, just not effectively and not as often as needed.

Cleared for takeoff list - simple steps to follow before surgery. Included a little metal tent to be placed over scalpels - removed by nurse after checklist - subtle reminder of the nurses authority to prevent surgery starting. Went from 2/3 of patients receiving antibiotics at correct time to 100%.

Another step added - team briefing. Everyone introduces themselves by name and role, and has a chance to discuss concerns and plans for possible complications. Distributes power/authority from surgeon to whole team. Improves teamwork. Improves reaction times in case of complication.

Lots of iteration with checklist eg first version did not specify it was supposed to be run through out loud with everyone.

### The checklist factory

Pilots have huge book of checklists for all kinds of situations.

Good checklists are precise and efficient. Cannot teach user, only remind them of what they already learned. __This is a crucial point - the checklist is not telling experts what to do, it's helping structure and trigger trained memories.__

Can't be too long - rule of thumb is 5-9 items - limit of working memory. __Why does working memory matter? Isn't the point of the checklist to offload work from working memory?__.

Time also matters - after 60-90s people typically start skipping steps. Focus on the 'killer items' - the mistakes that are most dangerous and most common to skip.

Transcripts of flight accidents show that even under huge pressure, pilot training is sufficient to keep them smoothly running through checklists.

DO-CONFIRM checklist - do the work first, run through the checklist after. READ-DO checklist - carry out tasks as they are checked off.

Checklists are constantly tested and revised using simulators and data from real-life.

FAA is incredibly persistent in investigating failures and finding ways to prevent or react to them in future. 'Mistakes happen' is never accepted as an answer.

Takes on average 17 years for new treatments to be adopted for at least half of US patients. Problem is that knowledge has not been transformed into a simple, usable, systematic form.

By contrast, crash investigators issue huge, dense reports but checklist team spends enormous amount of time distilling and refining this into simple, actionable form.

### The test

Simple simulation of WHO checklist in a conference room revealed many errors and rough edges. Followed by several rounds of small-scale testing with specific surgical teams. Gradual rollout.

The checklists were not just imposed from the top down. They were presented as a voluntary measure and there was a constant process of buy-in, feedback and revision. Admins were strongly discouraged from making it mandatory.

Dramatic improvements from adoptees all over the world. Controlled for different times of year, different kinds of operations. Observers present before and after so no Hawthorne effect. Effects were large in both poor and rich hospitals in many different cultures.

### The hero in the age of checklists

If a new medical device could claim the same results as the checklist, it would be a $b invention. But adopting checklists is harder, requires people to check their egos.

Compares to the shift from maverick test pilot culture to modern checklist utopia.

Pabrai Investment Funds. Uses an explicit checklist when evaluating investments. Acts as a check against over-excitement, confirmation bias etc. Built from a list of past mistakes. Lots of basic, painstaking groundwork - very tempting to skip it. __This is interesting because it's not even imposed from outside. It's like their past selves imposing discipline on their current selves.__ Checklist also massively increased efficiency - made it very clear when enough information had been gathered to make a decision. __Reminds me of an [informal description I gave](http://scattered-thoughts.net/blog/2015/09/22/motivating-the-monkey/) of my process for getting unstuck. I wonder if I would benefit from formalizing it, to remind me not to skip steps?__

Hudson ditching. Media wanted to find a hero, to the point of misrepresenting the facts, but pilot keeps emphasizing the role of the crew and their training. Notes that in the preflight meeting the pilot and copilot can be heard discussing what they would do if there was an accident during takeoff.

Checklist isn't about being told what to do - it's about offloading the routing tasks so that you are free to focus on the parts that humans do best.

Cessna engine failure checklist: #1 FLY THE AIRPLANE. Reminds pilots not to get so focused on restarting engines that they crash into the ground.

Code of conduct for different professions have common core: selflessness, striving for excellence, trustworthiness. But aviation also adds 'discipline', which is rare in other fields.

Systems thinking. It's not enough to optimize only the parts (experts, tools, materials). Have to optimize their interactions, and the system as a whole. Collecting data and studying failure is such a basic step yet happens in hardly any fields.

### The save

Author describes lives saved by simple checks in his own practice.

## Thoughts

__I don't know where to start. This is not a book about checklists. It's a book about building complex systems out of human parts, and about the role of discipline and systems thinking in preventing catastrophic error.__

__It has many examples of [distributed cognition](https://en.wikipedia.org/wiki/Distributed_cognition) that I wasn't at all aware of. I was especially struck by the construction example, where the traditional top-down organizational structure is replaced by many autonomous groups tied together with a semi-automated coordination system. This is sci-fi level stuff and I've never even heard about it. Now I want to find out more. I'm sure other complex engineering fields (eg aerospace engineering) have similar systems.__

__A good chunk of the book focuses on the challenges of adoption and the various measures that helped or harmed the introduction of checklists in medicine. It sames like one crucial aspect in all cases is that the external system is not seen as imposing control on the people, but as being a helpful assistant that they can choose to make use of or modify. There are definitely crucial questions to address about who gets to change the system eg in the construction case, who is allowed to say that a certain kind of check is no longer needed in future?__

__The many uses of checklists remind me of sections in previous books on Fermi equations, cost/benefit analysis, priority lists etc. The common theme is that imposing external structure helps improve cognition by preventing mistakes that happen without conscious awareness, whether through lapses of attention, cognitive biases or bait-and-switch. An even simpler example is the various exercises at [Clearer Thinking](http://www.clearerthinking.org/), which generally just ask a series of questions. It's normally easy to put hard questions out of mind or ignore inconvenient facts without even really being aware of it, but much harder when it manifests as a blank text box on your screen. Since we don't have access/introspection to System 1, these techniques all help by externalizing the thought process into a place where it can be checked, debugged and improved over time.__

__Many of these systems also help by just moving load out of the conscious mind (Mindware has a lot to say about the limitations of the prefrontal cortex). Some procedures can be trained into System 1 (eg physical movements, simple acronyms) eg I notice safety checks for both shooting and climbing tend to involve physically touching instead of just looking, making the movement easier to build into unthinking habit (when I dream about climbing, I dream the safety checks too). Can think of checklists as solution for procedures that System 1 doesn't do a good job of learning.__

__Lastly, the subject of discipline and professional responsibility. It's a touchy subject in programming, which still has a hero approach in most places. I notice that the programmers are happy to adopt elements of this that feel like automation rather than external control - continuous integration, code review bots, issue trackers etc - but there is much less discipline on the more human side of things. No checklists for the design process, no standard code of security procedures etc. We're happy to automate, as long as it's done with code and not with a list of rules. Again, questions of power and control probably come into play there, but there is also the problem of ego and identity as experts.__

__Rereading this book has started me thinking about how to build such systems. It's not enough to just provide the software, you need a systems-level approach to the entire problem, from communication and interfaces to psychology and politics. I guess the place to start is by surveying success and failures - this may be the next step after I finish the next few weeks of cramming.__
