ffi = require('ffi')
import graphics, filesystem, timer from love
NES = require('NES')
Display = require('Display')

font = graphics.newFont('assets/fonts/RetroGaming.ttf', 12, 'none')
font\setFilter('nearest')

setFrameCallback = (nes, display) ->
	capturedFrames = 0
	nes\setFrameCallback(->
		-- TODO: frame recording - make this configurable
		if __MOONSCRIPT and love.keyboard.isDown('lshift') and love.keyboard.isDown('lctrl')
			s = display\capture!
			s\encode('png', "%04d.png"\format(capturedFrames))
			capturedFrames += 1
	)

loadROM = (file, isdata) ->
	nfs = require('nativefs')
	cart = isdata and file or assert(nfs.read(file))
	nes = NES(cart)
	nes\reset!
	display = Display(nes)

	setFrameCallback(nes, display)
	nes, display

nes, display = do
	if not __MOONSCRIPT
		if arg[2]
			loadROM(arg[2])
		else
			loadROM('assets/defaultgame/2048.nes')
	else
		loadROM(require('testrom'))

flushAll = ->
	jit.flush!
	jit.off!
	collectgarbage!
	collectgarbage!
	jit.on!

love.filedropped = (file) ->
	return unless file\open('r')

	data = file\read!
	file\close!

	if data\sub(1, 4) == 'PK\x03\x04'
		fdata = filesystem.newFileData(data, 'rom.zip')
		filesystem.mount(fdata, 'rom')
		fname = assert(filesystem.getDirectoryItems('/rom')[1])
		data = assert(filesystem.read("/rom/#{fname}"))
		filesystem.unmount('rom.zip')

	nes, display = nil, nil
	flushAll!
	nes, display = loadROM(data, true)

paused = false

love.gamepadpressed = (joystick, button) -> nes\gamepadpressed(joystick, button)
love.gamepadreleased = (joystick, button) -> nes\gamepadreleased(joystick, button)
love.gamepadaxis = (joystick, axis, value) -> nes\gamepadaxis(joystick, axis, value)

love.keypressed = (key, scan) ->
	switch key
		when 'f1'
			display\toggleShader!
		when 'f2'
			display\toggleFilter!
		when 'f3'
			display\toggleOverscan!
		when 'f5'
			love.event.quit('restart')
		when 'f10'
			flushAll!
			nes\getCPU!\reset!
		when 'f12'
			_G.DEBUG = not _G.DEBUG
		when 'p'
			paused = not paused
		when 'escape'
			love.event.quit!
		else
			nes\keypressed(scan)

love.keyreleased = (key, scan) ->
	nes\keyreleased(scan)

accum = 0
tickDuration = 0
dbgTextX, dbgTextY, dbgTextScale = 0, 0, 2

local debugDraw

draw = (dt) ->
	with graphics
		.clear(0, 0, 0, 0)
		.line(0, 0, 0, 0) -- workaround for bug in love 11.3
		.setFont(font)

	accum += dt
	if paused or accum <= 1 / 60
		dbgTextX, dbgTextY, dbgTextScale = display\render!
	else
		collectgarbage('stop')
		tickDuration = nes\tick!
		collectgarbage('restart')
		dbgTextX, dbgTextY, dbgTextScale = display\render(nes\getScreen!)
		accum = math.max(0, accum - (1 / 60)) % (1 / 60)

	debugDraw(dt, tickDuration) if DEBUG
	graphics.present!

love.run = ->
	timer.step!
	->
		import event from love

		event.pump!
		for name, a, b, c, d, e, f in event.poll!
			return a or 0 if name == 'quit'
			love.handlers[name](a, b, c, d, e, f)

		dt = timer.step!
		draw(math.min(1 / 20, dt)) if graphics.isActive!
		timer.sleep(.001) if dt < 1 / 59

		nil

debugDraw = do
	COLOR_LABEL = { .5, .6, .7, 1 }
	COLOR_INFO = { 1, 1, 1, 1 }
	COLOR_WARNING = { 1, .2, 0, 1 }

	DBG_BARS = { i, "|"\rep(i) for i = 0, 10 }

	LOAD_COLORS = { [0]: { 0, 1, 0, 1 }, [100]: { 1, .2, 0, 1 } }

	frame = 0

	getLoadColor = (pct) ->
		pct = math.floor(math.max(0, math.min(100, pct)) + .5)
		if c = LOAD_COLORS[pct]
			return c

		v = pct * .01
		c = { v, math.min(1, 1.2 - v * v), 0, 1 }
		LOAD_COLORS[pct] = c
		c

	(dt, tickDuration) ->
		with graphics
			text = do
				loadPct = 100 * (tickDuration / (1 / 60))
				numPctBars = math.min(10, math.ceil(loadPct / 10))
				fps = timer.getFPS!
				garbage = collectgarbage('count')
				{
					COLOR_LABEL, "FPS:"
					COLOR_INFO, "%3d "\format(fps)

					COLOR_LABEL, "MEM:"
					COLOR_INFO, "%5.1fM "\format(garbage / 1024)

					COLOR_LABEL, "T:"
					getLoadColor(loadPct), "%3.0f"\format(tickDuration * 1000)
					COLOR_LABEL, "ms %s "\format(paused and "(paused)" or "")

					getLoadColor(loadPct), DBG_BARS[numPctBars]
					{ .4, .4, .4, 1 }, DBG_BARS[10 - numPctBars]
				}

			tx, ty = dbgTextX + 8 * dbgTextScale, math.max(0, dbgTextY + (8 * (dbgTextScale - 2)))
			for i = 0, 1
				.setColor(i, i, i)
				.printf(text, tx + i, ty + i, .getWidth! * 2, 'left')
			frame += 1
