# aerobuild
Scripts simplifying programming of glowing juggling props from aerotech. http://www.aerotechprojects.com

# build.pl

options:
```
--input \<input file\>
--num \<number of props/output files\>
--labels \<label file\>
--debug
```

# visualize.pl
the script creates a video (using avconv), simulating the light sequences of multiple glowing juggling props.
it is possible to include an audio file into the video

dependencies:
- avconv
- libx264
- libvo_aacenc

options:
```
--input \<glo input files\>
--audio \<audio file\>
--width \<output width\> (default: 640)
--height \<output height\> (default: relative to width / 16:9)
--output \<output file name\> (default: output.mp4)
--fps \<output frames per second\> (default: 30)
--amplify
--debug
```
