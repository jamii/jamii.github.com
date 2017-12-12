---
layout: post
title: Psychology vs the graphics pipeline
---

I often come across phrases in psychology papers like:

> [To test this prediction we exposed participants to photographs of faces (Experiments 1 and 2) or polygons (Experiment 3) [on a computer monitor] at suboptimal durations (40 ms) and optimal durations (400 ms).](https://pdfs.semanticscholar.org/0062/86ab72a28a5411adc3078cbdd4b9897a4d90.pdf)

This is interesting, because most modern monitors *cannot* display a photograph for exactly 40ms. At the typical [refresh rate](https://en.wikipedia.org/wiki/Refresh_rate) of 60hz you can display an image for 33ms or 50ms, but not 40ms.

This is not a big deal by itself, but the fact that the researchers *think* that they displayed an image for 40ms means that they didn't measure it at all. Which means it could be anything.

Unfortunately, few researchers share their code, and fewer still their hardware specs. For now I'll settle for using <testable.org> as a proxy measure. 

I [configured an experiment](https://gist.github.com/jamii/e3a96a0dcdb739c4c2104a1e6e216348) with image exposures ranging from 10ms to 100ms, followed by a mask until the user presses a key and then a 50ms pause between key-press and the next image. I recorded the experiment running on an [IPS](https://en.wikipedia.org/wiki/IPS_panel) monitor with a [240fps camera](https://www.slashgear.com/nexus-6p-240fps-video-camera-test-impressive-most-impressive-19410533/), because that's what I had to hand. 

First thing to note is that the image doesn't appear and disappear sharply - instead it fades in and fades out:

![](/img/firefox1.gif)

I recorded several other high-contrast videos to verify that this effect is not caused by the camera itself.

![](/img/contrast.gif)

IPS monitors are known to have particularly long response times, but all monitors will show this behavior to some extent. The result is that the image is still partially visible for some time after the mask appears. 

I recorded the experiment three times in Firefox 58 and counted the number of camera frames for which the image was fully visible by itself, and the number for which it was partially visible under the mask.

| Specified time (ms) | Expected frames | Trial 1 full | Trial 2 full | Trial 3 full | Trial 1 partial | Trial 2 partial | Trial 3 partial |
|---------------------|-----------------|--------------|--------------|--------------|-----------------|-----------------|-----------------|
| 10                  | 2.4             | 8            | 8            | 9            | 15              | 12              | 16              |
| 20                  | 4.8             | 4            | 5            | 8            | 19              | 16              | 16              |
| 30                  | 7.2             | 8            | 9            | 8            | 15              | 16              | 17              |
| 40                  | 9.6             | 12           | 9            | 12           | 18              | 17              | 16              |
| 50                  | 12              | 12           | 12           | 13           | 18              | 17              | 15              |
| 60                  | 14.4            | 17           | 17           | 17           | 17              | 16              | 18              |
| 70                  | 16.8            | 33           | 17           | 17           | 0               | 17              | 18              |
| 80                  | 19.2            | 20           | 21           | 20           | 16              | 17              | 20              |
| 90                  | 21.6            | 37           | 25           | 24           | 0               | 18              | 19              |
| 100                 | 24              | 36           | 25           | 24           | 0               | 18              | 20              |

The number of fully visible frames is roughly correlated with the specified time. There is some variance between trials, which presumably corresponds to how the animation frame in the browser happened to line up with the refresh rate of the monitor.

The number of partially visible frames is fairly consistent at around 16 frames / 67ms. That makes sense - we're just measuring the response time of the display itself rather than anything that varies with the specified exposure time. 

A couple of images in the first trial didn't get a mask at all and were instead exposed for much longer. I don't know the cause for this.

![](/img/firefox1.gif)

I also did the same thing in Chrome 62:

| Specified time (ms) | Expected frames | Trial 1 full | Trial 1 partial | Trial 2 full | Trial 2 profile (ms) |
|---------------------|-----------------|--------------|-----------------|--------------|----------------------|
| 10                  | 2.4             | 4            | 16              | 5            | 23.5                 |
| 20                  | 4.8             | 8            | 16              | 9            | 24.3                 |
| 30                  | 7.2             | 8            | 17              | 4            | 26.6                 |
| 40                  | 9.6             | 13           | 15              | 8            | 36.9                 |
| 50                  | 12              | 12           | 16              | 12           | 43                   |
| 60                  | 14.4            | 12           | 18              | 16           | 58.1                 |
| 70                  | 16.8            | 17           | 16              | 17           | 61.4                 |
| 80                  | 19.2            | 21           | 17              | 24           | 74.6                 |
| 90                  | 21.6            | 24           | 16              | 20           | 82.9                 |
| 100                 | 24              | 24           | 17              | 20           | 93.8                 |

The last column shows the time measured by the Chrome profiler during the second trial.

![](/img/chrome2.png)

The profiler shows the same rough pattern as the recording, but it fails to capture all of the variance eg from 80ms to 90ms the recording showed the number of frames dropped from 24 to 20 but the profiler reported that the frame duration increased from 74.6ms to 82.9ms. Clearly, if you care about actual exposure time on the screen it's not enough to rely on the profiler.

I also tried a slightly-older-but-still-high-end laptop with an internal IPS monitor.

| Specified time (ms) | Expected frames | Trial 1 full | Trial 1 partial |
|---------------------|-----------------|--------------|-----------------|
| 10                  | 2.4             | 9            | 10              |
| 20                  | 4.8             | 8            | 10              |
| 30                  | 7.2             | 12           | 11              |
| 40                  | 9.6             | 12           | 10              |
| 50                  | 12              | 17           | 11              |
| 60                  | 14.4            | 21           | 10              |
| 70                  | 16.8            | 21           | 11              |
| 80                  | 19.2            | 21           | 10              |
| 90                  | 21.6            | 29           | 10              |
| 100                 | 24              | 29           | 10              |

And an external IPS monitor over HDMI.

| Specified time (ms) | Expected frames | Trial 1 full | Trial 1 partial |
|---------------------|-----------------|--------------|-----------------|
| 10                  | 2.4             | 8            | 10              |
| 20                  | 4.8             | 8            | 14              |
| 30                  | 7.2             | 8            | 14              |
| 40                  | 9.6             | 12           | 11              |
| 50                  | 12              | 17           | 11              |
| 60                  | 14.4            | 16           | 13              |
| 70                  | 16.8            | 16           | 13              |
| 80                  | 19.2            | 20           | 14              |
| 90                  | 21.6            | 20           | 13              |
| 100                 | 24              | 32           | 13              |

The external monitor shows a slightly different update pattern, but otherwise the results are similar.

![](/img/external.gif)

Unfortunately, I don't have immediate access to any slower machines or to any other display technologies. I suspect that a cheap webbook or university lab thin-client might be more susceptible to dropping frames. But even on the high-end machines I've tested, I'm seeing a request for 100ms exposure produce actual exposures of 71-133ms plus additional partially-obscured exposures of 42-83ms. 

I'm not sure if this is a problem for priming experiments. The exact exposure time maybe doesn't affect the results that much. 

It may be a problem though for reaction time experiments, where the reaction time is measured from when the software believes the image is first displayed. On top of the variance in display time, there are similar sources of variance on the input side in keyboard polling intervals, device drivers and event queues. And I've seen a fair few experiments where the mean difference between conditions is <40ms, so the effects are small enough that this noise could at the very least reduce power.

So the next step is to figure out how to externally measure the accuracy of a reaction time experiment.
