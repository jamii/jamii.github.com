---
layout: post
title: Vive experiments
date: '2016-10-28 16:58'
---

I bought a [HTC Vive](https://www.vive.com/de/) during the summer and made some simple toys. These are all a few months old, but I didn't get around to writing anything down until today.

This is the first time I've found a VR experience convincing. I'm very susceptible to motion sickness in general, and every previous VR system I've tried has made me unhappy, sometimes for hours afterwards. The Vive is mostly fine, with the exception of a few games that break the published guidelines on acceleration. 

I found most of the games pretty disappointing. The vast majority just slap a VR headset on top of an existing game genre without paying any attention to the limitations or new opportunities of the platform. The hand controllers create an incredible feeling of presence and control, but most of the games are shoot-em-ups that use this incredible interface to replicate the point-and-grunt interaction of a mouse. A notable exception was [Fantastic Contraption](http://fantasticcontraption.com/), which has a ton of clever interface ideas, from the basic grab-and-manipulate building interaction to the summonable toolbox, the menu room contained in side a space helmet and the miniaturized levels in the load/save box. 

### Experiments

I really want to see experiences that could only make sense in VR, not just slightly more immersive versions of the same old games.

The first thing I tried myself was messing with the mapping from the real to the virtual world, to see if I could produce something similar to the [Pinocchio illusion](https://en.wikipedia.org/wiki/Pinocchio_illusion). Messing with the mapping of my hands just made me feel like the controllers were mounted on invisible sticks. Messing with the mapping of my head produced instant nausea and disorientation, no matter what what kind of changes I made.

I made a [monkey ball](https://www.youtube.com/watch?v=K6oz2mlV-Wk)-like toy where the goal is to stay close to several moving spheres without being touched by them. It's fun in real life, but in VR the headset feels like it's about to fall off. I later noticed this in other games and in videos of other people playing - anything that involves tilting the headset past 45 or so degrees feels dangerous.

<iframe width="560" height="315" src="https://www.youtube.com/embed/cS3SJiBNJxE" frameborder="0" allowfullscreen></iframe>

There are buzzing noises in that video. I added simple 3D sound to each ball to see if I could locate them with my eyes closed. I could only tell left side vs right side, nothing more specific. That's only a very basic sound engine though, I haven't tried with one of the fancy ones that simulates the effects of eg ear shape on the perceived sound. 

The next toy used the hands instead of the head, and involved catching trails of bubbles before they pop. This is oddly satisfying - I would just play with it for fairly long stretches of time.

<iframe width="560" height="315" src="https://www.youtube.com/embed/9wVkoYc9_Cc" frameborder="0" allowfullscreen></iframe>

Sometimes my arms would end up tangled and I would want to spin my whole body to untangle them, but then the headset would get tangled or move around. 

Full-body movements in general seem to run afoul of the headset and it's tether. It's not unworkable, but it's a constant minor annoyance in any game that requires moving quickly or unexpectedly. 

Large-scale movement around the virtual world is also tricky. Any acceleration in-game tends to produce motion sickness. One [grappling-hook -based game](https://www.youtube.com/watch?v=5k-T_s9L2I8) pretty reliably caused myself and everyone else I tested it on to stumble and wobble. The other games I played all either limited the player to a small space or had some kind of teleportation. 

I didn't find either of these very satisfying so I tried to find other movement mechanics that wouldn't cause motion sickness. I noticed that the Unreal Engine editor controls, where one grabs the world and moves it, didn't give me any problems, so I tried something similar in a zero-gravity setting.

<iframe width="560" height="315" src="https://www.youtube.com/embed/R_lIMubTdos" frameborder="0" allowfullscreen></iframe> 

Here the player can grab hold of beams and use them to pull and push themselves around. I really liked the result - free movement and totally nausea free. I want to play some kind of [racing / obstacle-avoidance game](https://www.youtube.com/watch?v=JIsQRvRAFk4) using this mechanic.

Some recent games have a similar 'skiing' mechanic where the player walks around by grabbing the air and pulling, alternating each hand. It's not as much fun as 

There's an interesting design problem when it comes to using both hands. If each hand grabs the same beam and then the player moves their hands apart, what happens? In the real world their hands simply wouldn't move, but we don't have that choice in VR. In the video above, whichever hand grabs last wins, but I later had the much more fun idea of making the player smaller to fit in the same space. 

<iframe width="560" height="315" src="https://www.youtube.com/embed/4R-hkq2ApgQ" frameborder="0" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/kU92H76c4TM" frameborder="0" allowfullscreen></iframe>

I also allowed the player to rotate themselves in a similar way. This turned out to be a really bad idea. The first time I tested it I immediately had to take off the headset and sit down. It's really interesting that the linear motion and zooming are totally fine, but rotation is instantly bad.

Another direction I thought about was strategy games. There are very few good 3D strategy games on the desktop because it's incredibly hard to understand and control a 3D scene with 2D input and display. 

I played around with a control scheme for a real-time game where the player grabs spaceships and drags to set their desired velocity vector, and then the ship accelerates until it's velocity matches.

<iframe width="560" height="315" src="https://www.youtube.com/embed/uG8pKvmbVa8" frameborder="0" allowfullscreen></iframe>

I'd like to go back and explore that more at some point.

### Tools

All the above experiments were developed in Unity. I also tried Unreal Engine and Stingray. I really disliked all three.

All three editors are really heavily oriented towards hand-built environments. The interfaces revolve around the level editor and the unit editor, neither of which are helpful if you want to randomly generate content, or start with an empty scene. 

Unity's hot-code loading should be a win for iteration time, but it's totally broken. The serialization breaks shared pointers. The VR library doesn't reinitialize properly. It was completely unusable for me.

Unity's Entity Component System sounds nice in theory, but the OO-esque implementation in terms of mixins and callback methods means that practice it degenerates into the same dispatch soup that bad OO programming does. Worse, you're forced to write in that style because most of the subsystems only expose data by calling events on specific entities. 

Here's a specific example. The collisions system runs and produces a list of collisions. Rather than returning that list, it calls the OnCollide callback on each of the components on each of the entities that collided. Since I can't do anything about the collision until the Update callback gets run later in the frame, I have to just store the collision object and set a flag. Effectively I'm forced to write code to take the list of collisions and turn it into a list of collisions. Except that the second list is spread out across a hundred objects. 

Here's another example. You are encouraged to put most of the gameplay logic into the Update callback which runs once a frame. Unfortunately, the order in which the callbacks are run across entities is not specified, so logic that relies on reading the state of other entities is now subject to non-deterministic bugs. I want to take the current list of positions of each entity, run some logic and generate a list of new positions, but doing within Update requires either mutating positions in place before other logic runs, or delaying movement to the start of the next frame. Worse, the positions of the VR controllers updates whenever they receive data from the hardware - not at any specific point in the frame. If you want to store the previous positions, there is no callback that you can implement that will reliably do so. For the movement experiments above I ended up circumventing the entire system, using a single god object with a callback that runs once per frame and schedules all the rest of the work itself, including calling into my patched version of the VR library to apply position updates at known points in time.

I spent far more time trying to get stuff working in Unity then I spent on the actual experiments themselves. I just want to put a couple of arrays in a 20 line script and hit a run button. Where is the [LÖVE](https://love2d.org/) of the VR world?
