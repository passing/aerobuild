# aerobuild
Scripts simplifying programming of glowing juggling props from aerotech. http://www.aerotechprojects.com

Supports syntax as described in *User guide V2.3*

## build.pl

### options
```
--input <input file>
--num <number of props/output files>
--labels <label file>
--debug
```
### features

#### conditons

glo file
*example to make clubs 1 & 3 red, club 2 blue and all others green*
```
<1,3>
C, 255, 0, 0
<2>
C, 0, 0, 255
<default>
C, 0, 255, 0
<end>
END
```

result:
```
; <1,3>
C, 255, 0, 0
; <end>
END
```
```
; <default>
C, 0, 255, 0
; <end>
END
```

#### align sequence to audacity labels

label file:
```
17.606795       17.606795       a
21.781043       21.781043       b
```
glo file:
```
;L-a
C, 255, 0, 0
;L-b
C, 0, 255, 0
END
```
result:
```
D, 1760 ;L-a
C, 255, 0, 0
D, 418 ;L-b
C, 0, 255, 0
END
```

## visualize.pl
the script creates a video (using avconv), simulating the light sequences of multiple glowing juggling props.
it is also possible to include an audio file.

### dependencies
- avconv
- libx264
- libvo_aacenc

### options
```
--input <glo input files>
--audio <audio file (mp3)>
--width <output width> (default: 640)
--height <output height> (default: relative to width for 16:9 ratio)
--output <output file name> (default: output.mp4)
--fps <output frames per second> (default: 30)
--amplify
--debug
```

*amplify* flag causes color components to be manipulated (low values are raised using sqrt function).
The resulting colors look more like the colors the glowclubs generate.

*width* option is useful to speed up encoding (e.g. 160)

### constraints
* strobing effects faster than the fps cannot be visualized / results can look quite bad
* implementation of the RAMP command is simplified
