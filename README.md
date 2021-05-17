# LEDpijp / GLSLpijp

**LEDpijp** receives 24-bit uncompressed video over USB/serial and displays it on LEDs.
There are many similar tools. This one works well on 8-bit AVR microcontrollers like the Nano.

**GLSLpijp** sends a video stream from a computer to zero or more microcontrollers running LEDpijp.

## Features

- [Live coding](https://en.wikipedia.org/wiki/Live_coding) GLSL shaders
- plays video files (MP4, MKV, GIF, etc)
- reliable 2 megabaud communication on AVR ATmega328 (with CH340)
- screensavers when no video is being received
- configuration stored on the microcontroller(s)
  - no USB COM port numbering shenanigans
  - simple to stream other [Processing](https://processing.org/) sketches

## Usage

- Run the `GLSLpijp.pde` sketch in [the Processing IDE](https://processing.org/download/). You should see Pacman munching disco biscuits. The sketch works without any connected microcontrollers or LEDs, but it's not as much fun like that.
- [Install the Arduino IDE](https://www.arduino.cc/en/Main/Software) then use the [library manager](https://www.arduino.cc/en/Guide/Libraries) to install FastLED.
- Configure each panel of your LED matrix in `XYmatrix.h`. Remember to change `XY_PANELID` before uploading to each microcontroller.

Press keys to change things while running GLSLpijp:

| Key(s)  | Action
|---------|----------------------------------------------------
|  space  | pause/resume sending stream
| `,` `.` | cycle through GLSL shaders
|   `o`   | open a video file
|   `s`   | cycle through screensavers
| `←` `→` | seek video file
| `↑` `↓` | zoom video (mousewheel also works)
|click and drag| pan around the movie
| `b` `B` | decrease/increase FastLED brightness
| `g` `G` | Gamma correction
| `f` `F` | change desired FPS
| `l` `L` | cycle LED order (32 different combinations)
| `/` `?` | stats for nerds or show panel configs
| `c` `C` | change serial chunk size (check stats for nerds for received FPS and bad/good frame counters)
| `t` `T` | change the minimum delay between sending frames

## Live coding and running other GLSL shaders

The current shader is automatically reloaded whenever it is modified on disk. If the shader gives compilation errors, they are shown on the Processing console and the last working shader continues to run.

To add a new shader, put it in a new `.glsl` file in the `LEDpijp\GLSLpijp\data\` folder. There's no need to restart GLSLpijp. You can immediately navigate to it using the `,` or `.` buttons.

You may find some shaders give error messages in Processing; if there's a line near the top like `#extension GL_OES_standard_derivatives : enable`, try commenting it out.

## Streaming other Processing sketches

Copy `LEDpijp.pde` into the sketch folder. Add this at the top of the sketch you want to run:

    LEDpijp ledpijp = new LEDpijp(this, 2000000);

Add this at the bottom of the `draw()` function:

    ledpijp.send();

If what appears on your LEDs is stretched, change the sketch's `size()` to match the aspect ratio of your matrix. If you'd like the Processing window to be resized to match the aspect ratio of your matrix, remove any existing call to `size()` in `setup()` and add this near the top too:

    void settings() {
      size(ledpijp.suggestedwidth, ledpijp.suggestedheight, P3D);
    }

## Performance

Tested with WS2812B LEDs, using cheap Nano clones driven by a 10-year old PC. MCUs with better USB connectivity will probably benefit from a larger chunk size than 64-bytes.

|FPS |Layout |LEDs |microcontroller(s)
|----|-------|-----|------------------
|75  |16 x 16|256  |1 Nano
|72  |32 x 16|512  |2 Nanos
|52  |32 x 24|768  |3 Nanos
|43  |32 x 32|1,024|4 Nanos

## Shortcomings

- Video playback is fragile. If a video is already playing, sometimes you have to press `o` twice to open another video. Spamming ffwd/rwd can break it. Playing videos with a faster framerate than your setup can sustain is especially prone to weirdness, and may waste many RAMs and squander your SSD wear.
- As it stands, it doesn't support multiple panels attached to a single MCU. I got fixated on the whole one Nano per panel thing and this is where we ended up.
- There is nothing to sync all panels, apart from USB packet reception. This might become noticeable when using many panels.
- The screensavers soon become out-of-sync on multi-panel setups. Fixing that needs a sync wire and some code to use it.

## Acknowledgements

[FastLED](http://fastled.io/) does the difficult bit of efficiently driving many different types of LED on many different microcontrollers.

All the shaders in `GLSLpijp/data` were borrowed from [GLSL sandbox](http://glslsandbox.com/) (NSFW possibly). Thanks to the authors, whoever they may be. I cluelessly modified some of them to suit smaller screens.
## License

[MIT](https://opensource.org/licenses/MIT), except the `GLpijp/data` folder.  Those authors didn't assert copyright, so I assumed it was public domain.
