# XenTuner - a MuseScore plugin

This plugin is for MuseScore 4 and is intended to allow 
microtonal/xenharmonic composition with all the accidentals MuseScore 
supports. Since there is already good support for the graphical 
accidentals, this plugin only affects playback. The way it works is you 
create a file representing how you want the naturals (notes A-G) to be 
tuned, and by what amount each accidental should modify a pitch. Then 
just run the plugin and a tuning adjustment will be added to each note 
so it actually sounds in your tuning. See the example files to 
understand the format and what is possible.

The "naturals" property in the tuning file must be in cents, but 
otherwise works similarly to Scala SCL files. Namely, the first note of 
the scale (middle C) is assumed to be 0 cents and then the given cents 
values specify the 2nd thru (n+1)th pitches of the scale. The last one 
is also the period of the scale in cents, e.g. for any 
pure-octave-repeating scale it would be exactly 1200.0.

The "middleCPitch" property can be used to shift the overall absolute 
tuning of the scale by specifying the offset of middle C (in cents) from 
the standard concert pitch of 261.6255653... Hz.

## CAVEATS

* Does not support custom key signatures (since they aren't exposed to 
the plugin API yet). Only the 15 standard key signatures work, the ones 
with single sharps and flats following the circle-of-fifths rules.

## Getting Started

Make sure MuseScore 4.4 or later is installed (tested with 4.5.2).

Put xentuner.qml from this project somewhere MuseScore can find it, for 
example the default plugin folder where the other plugins are.

Go to Plugins -> Plugin Manager and enable it. It should appear in the 
plugins menu as "Xenharmonic Tuner".

Run the plugin and try out one of the example files.

## Authors

* **Keenan Pepper**

## License

This project is licensed under the GPL version 3. (Mostly just because a 
useful chunk of code came from another plugin that was GPL3 licensed.)
