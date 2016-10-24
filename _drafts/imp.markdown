---
layout: "post"
title: "Imp"
date: "2016-10-24 14:19"
---

Spreadsheets are awesome, super successful. 

* Incremental - value add as soon as data is in
* Always now - static model is easier to understand
* Immediate + concrete - example data in face, don't have to hold it in head
* Direct - point at things to reference or change them
* Transparent - if you can see a thing, you can change it without any extra actions (cloning, compiling, finding source, copying data)
* Self-explaining/justifying - click on a cell to find out where it came from
* Safe - undo for both data and code (and VC in sheets), no forgetting the past

But bad at some things.

* Non-time-series data / joins
* Time and change
* Performance
* Interaction / UI
* Sharing and collaboration
* Inspection - logic is spread out and hard to review / debug

Want to keep the good stuff and fix the bad stuff. So I built:

* Relations and relational queries
* Model of time handling external change, internal change and version control 
* Fast enough to do X impressive thing
* GUI toolkit
* ...some kind of collaboration model?

Examples of stuff that is kept:

* Interactive table modification
* Interactive view modification
* Explore through foreign keys
* Undo / version control
* Provenance for data
* Provenance for UI (click on element to get code that created it)

Examples that spreadsheets would struggle with

* Time-series analysis that needs complex state per time-point
* Betting exchange - removal of past states
* Push notifications / actions 
* React to timers
* Large amounts of data
* Connect to outside data source
* Text search?
* Multiple versions. Explore through timeline. Merge.

Non-goals

* 'End-user friendly'
* 'Scalable'
