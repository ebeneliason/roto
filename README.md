# Roto

[![MIT License](https://img.shields.io/github/license/ebeneliason/roto)](LICENSE) [![Toybox Compatible](https://img.shields.io/badge/toybox.py-compatible-brightgreen)](https://toyboxpy.io) [![Latest Version](https://img.shields.io/github/v/tag/ebeneliason/roto)](https://github.com/ebeneliason/roto/tags)

_Export Playdate sprite sheets from procedurally drawn graphics._

## What is Roto?

Roto is a utility for use with the [Playdate Simulator](https://help.play.date/manual/simulator/).
Use it to generate tiled sprite sheets or image sequences from animated graphics drawn procedurally using
the [PlayDate drawing APIs](https://sdk.play.date/1.13.2/Inside%20Playdate.html#_drawing). These files may
then be loaded into [`imagetable`s](https://sdk.play.date/1.13.2/Inside%20Playdate.html#C-graphics.imagetable)
for playback in place of the procedural calls.

### Why would I use it?

Consider using Roto when:

1. You want to optimize graphics performance, and…
2. You have already created procedurally drawn sprite graphics, or…
3. Generating your graphics procedurally would be more efficient than achieving the same results by hand.

Rendering pre-drawn image sequences is significantly faster on device than rendering graphics procedurally
using the Playdate APIs. However, if _generating_ the graphics procedurally is easier (or if you've _already_
implemented your sprites using the drawing APIs), Roto can make the process of transitioning to pre-rendered
sprite sheets easy.

### What's With the Name?

Roto gets its name from [Rotoscoping](https://en.wikipedia.org/wiki/Rotoscoping), a 2D animation process in
which animators trace over individual frames of video to produce lifelike animation. In effect, the Roto
instance "traces" the graphics of your sprite each frame.

## Installation

### Installing Manually

1.  Download the [Roto.lua](Roto.lua) file.
2.  Place the file in your project directory (e.g. in the `source` directory next to `main.lua`).
3.  Import it in your project (e.g. from `main.lua`).

    ```lua
    import "Roto"
    ```

### Using [`toybox.py`](https://toyboxpy.io/)

1.  If you haven't already, download and install [`toybox.py`](https://toyboxpy.io/).
2.  Navigate to your project folder in a Terminal window.

    ```console
    cd "/path/to/myProject"
    ```

3.  Add Roto to your project

    ```console
    toybox add ebeneliason/roto
    toybox update
    ```

4.  Then, if your code is in the `source` directory, import it as follows:

    ```lua
    import '../toyboxes/toyboxes.lua'
    ```

## Features

1.  **Sprite Capture.** Capture procedurally drawn sprite animations individually as pre-rendered sprite images.
2.  **Start & Stop.** Dynamically start and stop capture so you get only the frames you need.
3.  **Save to File.** Save captured animations as image sequences or tiled sprite sheets.
4.  **Live Previews.** Preview your captures live in the simulator. This even works with randomized drawing,
    so you can repeat the capture process until you see one you'd like to save.

## Limitations

Roto has a few known limitations:

1.  **Dither Patterns.** Any dither patterns wind up drawn with phase zero, as they begin relative to the top
    left corner of the captured frames. As such, any effects achieved by moving the sprite "through" a dither
    pattern in world space will not have any effect in the captured images.
2.  **Transformations.** Rotations (e.g. `playdate.graphics.sprite:setRotation`) or other "external" transformations
    or modifications applied to the sprite itself will not be reflected in the captured frames. (Any
    transformations or effects applied on images or objects drawn directly within `draw` are preserved.)
3.  **Performance.** Using Roto may result in a _slight_ performance impact while actively tracing, though it
    should be minimal. Saving may also cause a momentary hang depending on the number of captured frames.

## Usage

_NOTE: Roto **only** works within the Playdate Simulator. Attempts to utilize Roto on device will cause
an assertion failure._

### The TL;DR Version

```lua
import "Roto"

-- Initialize a Roto instance for the sprite you wish to generate assets from
local mySprite = MySprite()
local roto = Roto(mySprite)

-- Start capturing frames, perhaps in response to a button press or state change event
roto:startTracing()

-- Let some number of frames pass…

-- Stop capturing frames, perhaps in response to a button press, event or timer
roto:stopTracing()

-- Save a sprite sheet containing the captured images
roto:saveAsMatrix("~/Desktop")

```

### Creating a Roto Instance for Your Sprite

Roto makes it extremely easy to capture the rendered content of your sprites. You won't need to make any
modifications to your sprite or its `draw` function. You can create a Roto instance for each sprite you
wish to capture by passing it a reference to your sprite.

```lua
local mySprite = MySprite()
local roto = Roto(mySprite)
```

### Choosing When to Trace

You'll likely only want to capture a particular sequence of frames. Roto gives you full control, letting
you start and stop the tracing in response to events (game state, buttons presses, keys, etc.) or timers.

```lua
roto:startTracing()

```

```lua
roto:stopTracing()
```

You can also call these functions directly on the sprite which you've initialized with Roto. This makes
it easier to control from anywhere you have a reference to the sprite.

```lua
mySprite:startTracing()
mySprite:stopTracing()
```

Finally, if you know the number of frames you wish to capture in advance:

```lua
roto:startTracing(12) -- only capture 12 frames
mySprite:startTracing(12) -- works here, too
```

### Saving Matrix Images

Save the traced frames as a matrix image table, or "sprite sheet", providing a directory in which to
save the resulting image.

```lua
roto:saveAsMatrix("~/Desktop/")
```

The file will be named `MySprite-table-<w>-<h>.png` where _w_ and _h_ are the width and height of each
frame cell. Note that if the sizes of the individual captured frames are not all equal to the cell size
of the matrix image, the smaller frames will be centered within their respective cells.

If you'd like to name the file something other than the sprite class name, provide a second argument
with the desired prefix.

```lua
roto:saveAsMatrix("~/Desktop/", "AnotherName") -- "AnotherName-table-<w>-<h>.png"
```

By default this function will produce a matrix that is approximately square, according to the total
number of frames. If you wish to specify the desired number of frames per row, provide a third
argument.

```lua
roto:saveAsMatrix("~/Desktop/", "MySprite", 10) -- 10 frames per row
```

### Saving Image Sequences

If you prefer, you can also save your captured frames as a numbered sequence of images. All resulting
image files will have names of the form `MySprite-table-<N>.png`, where _N_ is the frame number.
Frame numbers will be padded with leading zeros according to the total number of frames.

```lua
roto:saveAsSequence("~/Desktop/MySequence")
```

Note that all images will be saved directly into the specified directory. It's recommended that you
create a new empty directory to save them into. If you specify a directory path with a trailing path
segment which doesn't yet exist, it will be created for you.

If you'd like to name the files something other than the sprite class name, provide a second argument
with the desired prefix.

```lua
roto:saveAsSequence("~/Desktop/", "AnotherName") -- "AnotherName-table-<n>.png"
```

### Loading Your Saved Files

You can load both the matrix and sequence image tables for use within your sprites. You can use the
[`playdate.graphics.imagetable`](https://sdk.play.date/1.13.2/Inside%20Playdate.html#C-graphics.imagetable)
API to load them:

```lua
playdate.graphics.imagetable.new("Images/MySprite") -- note omission of -table-* suffix
```

See the [Playdate SDK docs](https://sdk.play.date) for additional details.
