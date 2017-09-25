---
layout: post
title: Notes on 'Designing with the Mind in Mind'
---

<https://smile.amazon.com/dp/B00HLLN0PI/>

UI guidelines easier to understand if we understand the cognitive basic, especially in novel contexts.

Need explanatory model for:

* explanatory evaluation
* generative design
* codification of knowledge

A/B testing without a model is like driving by bouncing off the guard rails.

## Biased perception

* Perceptual priming
* Familiar frames 
  * next/back buttons
  * UI needs to be consistent, because the user will see what they expect to see, not what is actually there
* Habituation
  * eg dismissing warning messages without reading them
* Attentional blink
* Top down bias (cf [PP](https://slatestarcodex.com/2017/09/06/predictive-processing-and-perceptual-control/))
  * eg McGurk effect
  * eg ventriloquism
  * eg illusory flash
* Guided + filtered by goals
  * Guides gaze and attention
  * Primes perception
  * eg cocktail party effect

* Avoid ambiguity
  * Test that all users thave the same interpretation
* Stick to convention
* Be internally consistent
* Understand users goals and map UI elements to goals

## Structure

* Vision automatically groups features into structure based on:
  * Proximity
  * Similarity
  * Movement (common fate)
  * __Alignment__
* Also resolves ambiguity with bias for:
  * Continuity - hidden forms (eg sliders)
  * Closure - whole objects (eg stacks)
  * Symmetry - low complexity scene (eg seeing complex 2d image as simple 3d scene)
* Figure/ground
  * By features, but also by attention
  * eg watermark behind text

* Inspect UI for unintended relations

## Color

* Rods max out in typical env
* 3 kinds of cones - low/med/high freq (for most people, actually 2-4 in general)
* High-freq cones much less sensitive than low/med-freq
* Cone signals combined into subtraction channels
  * Med - low = red/green
  * High - low = yellow/blue
  * Med + low = black/white 
* Then do edge detection -ish - subtract neighboring signals

* Optimized to detect contrast, not brightness
* Less able to distinguish regions of colour which are:
  * Pale
  * Small/thin
  * Far apart
* User won't see same colors as you
  * Color blindness = one or more cone kinds less sensitive
  * Different displays
  * Display angle
  * Ambient light/shadow
* Choose colors that contrast strongly on at least one channel
* Use redundant cues - color, weight, size, placement, symbols, text
* Test using color blindness simulators and grayscale
* Don't place opposing pairs (red-green, yellow-blue, black-white) next to each other - causes shimmer

## Search

* Users scan for structure > reading for content
* Avoid burying structure in noise
* Create visual hierarchy with:
  * Positioning (top/bottom)
  * Grouping
  * Size/weight
* Chunk info 
  * eg allow users to put spaces in phone and credit card numbers
  
## Peripheral

* Fovea is about 1% of visual field - thumbnail at arms length
* Much higher 'resolution' in fovea
  * Cone:rod is ~20:1 inside fovea vs ~1:20 outside
  * Signals from outside fovea are increasingly lossily compressed
  * ~50% of visual cortex dedicated to signals from fovea
* Peripheral vision typically as bad as ~20/200 = legally blind
* Peripheral guides gaze
  * Detects motion
  * Perceives large patches of color
  * Sensitive to low light
  
* Message placement
  * Put where the user is looking already
    * eg pressing sign-in button and error appears at top of page - invisible in peripheral
  * Use conventional error symbols
  * Reserve red for errors
  * Catch errors early while user is still looking at that input
* Popup, shake, beep will get attention but:
  * Annoying
  * Can be mistaken for ad
  * Habituation
  * => Last resort for really urgent errors
* Search is linear, but can parallel scan for features that peripheral vision can see
  * eg search for z vs search for bold letter
* Don't move items - requires vision instead of muscle memory
  * eg menu placement by most recent
* Try to make items primable 
  * eg searching for errors = searching for red or error symbol
  
## Reading

* Not innate
* Requires detailed vision
  * Width of fovea is ~6-8 chars
  * Can see ~30-40 chars blurrily
  * Biased in forward language direction eg Euro readers can see more chars to the right 
  * Saccade several times /s, ~100ms duration
* Movement is mostly linear, guided by peripheral vision
  * Usually land inside word
  * Can skip over small/predicatable words
  * Sometimes saccade backwards
  * At end of line, jump to guessed location of next line
* Both bottom-up and top-down processing
  * Early theories suggested top-down dominates (eg speed-reading schools) but no longer believed
  * Top-down is more dominant in less-skilled readers than in more-skilled readers
  * Top-down is more dominant in poor conditions
  * __I'm interpreting this to say that in skilled readers the bottom-up signal is strong enough to overwhelm any top-down signal__
  
* Avoid 'poor conditions'
  * Uncommon or unfamiliar vocab
    * Especially technical jargon
  * Difficult fonts 
    * eg all-caps
  * Small text
  * Noise background
    * Think how hard captchas are to read
  * Excessive repetition - makes it easy to lose track of position
  * Centered text - can't easily jump to start of next line

## Long-term memory

* High-capacity, low-fidelity, error-prone
* Experiences are highly compressed - not raw sensory data
* Different kinds:
  * episodic - past events
  * procedural - action sequences
  * semantic - facts and relationships
* Weighted by emotion
* Retractively alterable

* Password requirements - allow for memorable phrases, not meaningless strings
* Security questions - let user pick their own
* Consistency = less steps to remember
* Discoverability - for actions the user has forgotten

## Working memory

* Working memory not a 'place' - not RAM
* (__Not confident in my understanding of this section:__)
  * Each perceptual system has some internal representations which can be repeatedly refreshed (instead of processing current inputs)
  * Long-term memory patterns can be activated by percepts or recall and then repeatedly refreshed
  * Working memory consists of applying limited focus/attention to a small number of items
  * Everything outside of that focus is at risk of fading away
* 3-5 items, but controversy over what exactly should be measured
  * eg items with more features lower limit, so should we count features instead of items?
* Chunking
* Items can be both pulled into working memory by conscious processes or pushed by automatic processes
* Strong candidates for involuntary pushing:
  * Motion (especially near or towards)
  * Threats
  * Faces
  * Sex and food
  * Goals / primed patterns
  
* Modes and mode error
  * Avoid modes or provide very clear signals
* Keep task-relevant info on-screen in case it falls out of working memory
  * eg search engines now show the search query above the results
  * Keep instructions open while user is following instructions
* Calls to action - max 1 per message
* Navigation depth => breadcrumbs

## Goal-seeking

* Goals decompose into nested subgoals - strains working memory
* Having to spend limited attention/memory on tools may push out goal structure
  * Familiar paths = low cognitive load, less risk of derailment
  * For non-frequent tasks prefer mindless funnel over mechanical efficiency
  * For frequent tasks still provide funnel but also hint towards more efficient routes
* Percept + memory is goal-filterd
  * Inattentional blindness 
    * eg gorilla basketball
  * Change blindness
    * eg price change when changing options
* 'Following information scent' - scanning for next action
  * Priming is pretty literal eg 'buy' or 'ticket' but not 'bargain trips'
* External aids
  * eg tab lists
  * eg checklists
  * Let users mark/group objects
* Goal-Execute-Evaluate loop
  * nested, multi-level
  * goal - map entry paths to common goals
  * execute - map actions to tasks, not implementations 
    * ie not git
  * eval - show progress / status
* Attention lost after goal, may miss cleanup tasks
  * do automatically if possible
  * remind user
  * delay goal satisfaction until after cleanup
    * eg atm
    
## Recognition vs recall

* Recognition
  * Retrieval with perceptual support
  * Percepts causes neural pattern which is similar to matching memories. No need for search.
    * (__How is the similarity detected?__)
  * eg choosing command from list
* Recall
  * Retrieval without perceptual support
  * eg typing commands from memory
* Better at recognizing images than text 
  * => icons
* Scale-invariant
  * => thumbnails
  
* Use common themes for site so user can recognize when they arrive/leave

## Automatic vs controlled

* Dual-system theory - S1/automatic, S2/controlled

* Do S2 work for the user
  * eg meeting planner shows times in all timezones, even though user could easily add the offset
* Replace calculation with perception
  * eg goto line -> scroll bar - easier to visually pick out halfway point than to count total lines and divide by 2
  * eg coordinates -> alignment guides - easier to drag until aligned than to add grid increments to coords
  
## Learning

* Controlled -> automatic
* Learn faster when:
  * Practice is:
    * frequent
    * regular
    * precise (__not clear what is meant by precise__)
  * Operation is:
    * Task-focused 
      * Nouns/verbs in same domain as problem, not implementation
      * 'Gulf of execution'
    * Simple
      * Features interact, so complexity is super-linear
    * Consistent
      * Predicatable, compressible
  * Vocab is:
    * Task-focused
      * Relative to what user cares about, not implementation
      * eg local/remote -> private/shared
    * Familiar
      * Guessible
      * Understood by S1
    * Consistent
      * Maps 1:1 to concepts
* Low-risk encourages exploration
  * Make mistakes impossible
  * Clearly detect errors
  * Allow undo or correct
  
## Bias

* Decision support systems
* Help avoid bias
  * Provide all options - prevents limited framing
  * Propose variations on user solutions - aids creative search
  * Perform calculations, comparisons, inference etc automatically
  * Let users declare assumptions and then check them automatically
* Vizualization - map problem domain into existing S1 processes
  * eg Chernoff faces (__vaguely recall reading that these are much less effective than originally claimed__)
* Persuasive systems - target S1 to influence users

## Hand-eye coordination

* Movement is open-loop ballistic followed by closed-loop correction
* Fitts law - $$T=O(\log(1+\frac{D}{W}))$$
  * Edge of screen is effectively infinitely wide - can hit it with open-loop only
* Steering law - to stay within path $$T = O(\frac{D}{W})$$
  * eg pull-right menus
  * eg old-school scrollbars

* Make targets big enough
* Make actual target >= visible target
* Accept clicks on labels
* Leave space between targets
* Put important targets near edge
* Pull-down menus -> pop-up menus - lower avg distance

## Time scales

* Reponsiveness > effectiveness for user satisfaction (many citations)
* Responsive doesn't necessarily mean fast.
  * Ack input
  * Give estimated waits
  * Let user do other things whilst waiting
  * Run non-user tasks in background, without blocking UI
    * eg GC
    * eg defrag

* ~5ms subliminal perception - visual priming, basic emotions
* ~100ms between visual event and full perception
  * But brain does lag correction + post-hoc editing
* <100ms limit of 'perceptual locking' between sound and visual event
  * eg drummer closing from distance - perceived lag doesn't go linearly to zero but instead jumps from 100ms to 0ms
* ~100ms saccade
* <140ms limit of intuitive (__physical?__) causality
  * eg typing with >140ms lag makes user conscious of act of typing 
* ~50ms / item to subitize
* ~300ms / item to count
* ~200ms editorial window, within which events can be reordered or edited before conscious experience
  * eg dot disappearing and appearing again will be perceived as having moved linearly if <200ms
* ~500ms attentional blink
* ~700ms visual-motor response
  * but ~80ms for flinch (__time to start of motion?__)
* ~6-30s unbroken attention to unit task before switch
  * (__think of this as scheduling quantum?__)
  
* Rules of thumb:
  * ~10ms sound, digital ink (__why is ink noticable but not other ui interactions? automaticity?__)
  * ~100ms ack, react, animate, hand-eye (eg drag+drop)
  * ~1s finish or estimate duration, user reaction to new information
  * ~10s unit task

* Use busy indicator for *anything* that blocks user input, even if normally <100ms
* Display important info first - rest can sneakily render while user is reacting
  * eg progressive rendering for images
  * eg approx results for database queries
* Delays between unit tasks are less derailing than delays within unit tasks
  * 'task closure'
  * eg delay on autosave => wait until typing stops
* For tasks requiring hand-eye coordination, fake it if you can't make it
  * eg scrolling just shows page boundaries, renders on pause
  * eg rubber-band resize
* Precompute high-prob tasks during low load
  * eg render next few pages while user is reading current page
* Start progress indicators at 1% and don't spend more than a few seconds at 100%
* Prioritize tasks queues according to user priorities
  

