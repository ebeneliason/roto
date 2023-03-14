import "CoreLibs/object"
import "CoreLibs/graphics"

local gfx <const> = playdate.graphics
local min <const> = math.min
local max <const> = math.max

class('Roto').extends(object)

-- Roto provides "rotoscoping" capabilities for Playdate sprites, enabling you
-- to capture frame sequences and then save them to files suitable for use as
-- pre-rendered `imagetable`s. Both sequence and matrix formats are supported.
--
-- Limitations:
--
-- 1. Dither patterns are local to the captured image, so moving the sprite
--    "through" one in world space will not have any effect.
-- 2. Rotations or other "external" transformations on the sprite itself will
--    not be captured (though any performed on draw calls will be).
-- 3. Rotoscoping may result in a slight performance impact, though it should
--    be minimal.
--
-- Usage:
--
--   local mySprite = MySprite()
--   local roto = Roto(mySprite)
--   roto.startTracing() -- perhaps in response to some event
--
--   ...
--
--   roto.stopTracing() -- perhaps in response to an event or a timer
--   roto.saveAsMatrix("~/Desktop")


-- Create a new Roto capable of tracing frames from the provided sprite to save to file
function Roto:init(sprite)
    FrameScore.super.init(self)

    -- ensure we don't wind up used in a build on device
    assert(playdate.isSimulator, "Roto should only be used with the simulator.")

    -- the sprite we'll be rotoscoping
    self.sprite = sprite

    -- the sequence of images for our imagemap
    self.frames = {}

    -- keep track of the largest and smallest frame size
    local w, h = sprite:getSize()
    self.minFrameWidth  = w
    self.maxFrameWidth  = w
    self.minFrameHeight = h
    self.maxFrameHeight = h

    -- whether we're actively capturing frames from the sprite
    self.tracing = false

    -- hijack the sprite's draw function
    sprite._draw = sprite.draw
    sprite.draw = drawHijack
    sprite.roto = self

    -- add some conveneinces to the sprite for controlling tracing
    sprite.startTracing = function(self, numFrames)
        self.roto:startTracing(numFrames)
	end

	sprite.stopTracing = function(self)
        self.roto:stopTracing()
	end
end

-- This function gets "installed" on the sprite passed to `Roto:init`,
-- overriding its provided `draw` function. As such all references to `self`
-- actually pertain the traced sprite, not to the Roto instance.
-- @param self The sprite instance being drawn
function drawHijack(self)
	if self.roto.tracing then
		-- keep track of the largest and smallest frame size we capture
		local w, h = self:getSize()
		self.roto.minFrameWidth  = min(self.roto.minFrameWidth,  w)
		self.roto.maxFrameWidth  = max(self.roto.maxFrameWidth,  w)
		self.roto.minFrameHeight = min(self.roto.minFrameHeight, h)
		self.roto.maxFrameHeight = max(self.roto.maxFrameHeight, h)

		-- draw the sprite into our roto image for future export
		local frame = gfx.image.new(w, h)
		self.roto.frames[#self.roto.frames+1] = frame
		gfx.lockFocus(frame)
			self._draw(self)
		gfx.unlockFocus()

		-- draw the captured image into the sprite itself
		frame:draw(0,0)

		-- decrement our capture counter, if needed
		if self.roto.numFrames then
			self.roto.numFrames -= 1
			if self.roto.numFrames <= 0 then
				self.roto:stopTracing()
			end
		end
	else
		-- if we're not actively tracing, just draw normally
		self._draw(self)
	end
end

-- Begin capturing sprite frames for export
-- @param numFrames?	An optional limit on the number of frames to capture
function Roto:startTracing(numFrames)
	if numFrames then
		print("Beginning roto capture (" .. numFrames .. " frames) for " .. self.sprite.className .. ".")
	else
		print("Beginning roto capture for " .. self.sprite.className .. ".")
	end
	self.tracing = true
	self.numFrames = numFrames
end

-- Stop capturing sprite frames for export
function Roto:stopTracing()
	print("Ending roto capture for " .. self.sprite.className .. ". Captured " .. #self.frames .. " frames.")
	self.tracing = false
	self.numFrames = nil
end

-- Reset, allowing capture of a brand new sequence of frames
function Roto:reset()
	print("Reset roto capture for " .. self.sprite.className .. ".")
	self.frames = {}

	local w, h = self.sprite:getSize()
    self.minFrameWidth  = w
    self.maxFrameWidth  = w
    self.minFrameHeight = h
    self.maxFrameHeight = h

	self.tracing = false
	self.numFrames = nil
end

-- Saves the captured frames as a numbered sequence of images
-- @param directoryPath		A path to a directory on the local filesystem to store the sequence in.
-- @param filenamePrefix?	An optional name to use for each image file, excluding the numbered table suffix and extension. Defaults to the sprite `classNmae`.
function Roto:saveAsSequence(directoryPath, filenamePrefix)
	assert(self.frames and #self.frames > 0,
		"No frames from " .. self.sprite.className .. " have been captured for export.")

	-- ensure single trailing slash on directory path
	directoryPath = directoryPath:gsub("/?$", "/")

	-- use the className of the sprite if no filename was provided
	if not filenamePrefix then
		filenamePrefix = self.sprite.className
	end

	local fullPath = directoryPath .. filenamePrefix .. "-N.png"
	print("Writing imagetable sequence to " .. fullPath)

	-- format string for padding sequence numbers with leading 0s
	local pad = math.floor(math.log10(#self.frames)) + 1
	local fmt = "%0" .. pad .. "d"

	-- iterate through frames and save to file
	for i, frame in ipairs(self.frames) do
		fullPath = directoryPath .. filenamePrefix .. "-table-" .. string.format(fmt, i) .. ".png"
		playdate.simulator.writeToFile(frame, fullPath)
	end
end

-- Saves the captured frames as a matrix image table
-- @param directoryPath		A path to a directory on the local filesystem to store the imagetable in
-- @param filenamePrefix?	An optional name to use for the image file, excluding the table suffix and extension. Defaults to the sprite `classNmae`.
-- @param cellsWide?		The number of frames per row in the output image. If omitted, the resulting image will be tiled approximately square.
function Roto:saveAsMatrix(directoryPath, filenamePrefix, cellsWide)
	assert(self.frames and #self.frames > 0,
		"No frames from " .. self.sprite.className .. " have been captured for export.")

	-- ensure single trailing slash on directory path
	directoryPath = directoryPath:gsub("/?$", "/")

	-- use the className of the sprite if no filename was provided
	if not filenamePrefix then
		filenamePrefix = self.sprite.className
	end

	-- determine an appropriate size for the table and its cells
	local numFrames = #self.frames
	local sqrtFrames = math.sqrt(numFrames)
	local cellsWide = cellsWide or math.floor(sqrtFrames)
	local cellsTall = math.ceil(numFrames / cellsWide)
	local w = math.floor(self.maxFrameWidth)
	local h = math.floor(self.maxFrameHeight)

	-- render the frames into each cell of the image
	local tiledImage = gfx.image.new(cellsWide * w, cellsTall * h)
	gfx.pushContext(tiledImage)
	for i, frame in ipairs(self.frames) do
		-- identify the top left corner of the next cell
		local r = math.floor((i-1) / cellsWide)
		local c = (i-1) - r * cellsWide
		local x = c * w
		local y = r * h

		-- offset the drawing position if the frame is smaller than our cell size
		x += math.floor((w - frame.width)  / 2)
		y += math.floor((h - frame.height) / 2)

		-- draw the image into the cell
		frame:draw(x, y)
	end
	gfx.popContext()

	-- lastly, save the resulting image to file
	local fullPath = directoryPath .. filenamePrefix .. "-table-" .. w .. "-" .. h .. ".png"
	print("Writing matrix imagetable to " .. fullPath)
	playdate.simulator.writeToFile(tiledImage, fullPath)

end
