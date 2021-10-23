import keyboard from love
import rshift, lshift, band, bor from require('bit')

A =      0
B =      1
SELECT = 2
START =  3
UP =     4
DOWN =   5
LEFT =   6
RIGHT =  7

IMPOSSIBLE = {
	[UP]: DOWN
	[DOWN]: UP
	[LEFT]: RIGHT
	[RIGHT]: LEFT
}

GAMEPADMAP = {
	a: A
	x: B
	back: SELECT
	start: START
	dpup: UP
	dpdown: DOWN
	dpleft: LEFT
	dpright: RIGHT
}

GAMEPADNOISE = .01
GAMEPADDEADZONE = .1
GAMEPADTHRESHOLD = .5

prevAxes = {}

class Controller
	new: (@_apu, @_addr, keys = {}) =>
		@_buttonMap = {
			[A]:      keys.a
			[B]:      keys.b
			[SELECT]: keys.select
			[START]:  keys.start
			[UP]:     keys.up
			[DOWN]:   keys.down
			[LEFT]:   keys.left
			[RIGHT]:  keys.right
		}
		@_buttonMap[v] = k for k, v in pairs(@_buttonMap)
		@_buttonState = { i, false for i = A, RIGHT }
		@_state = 0
		@_data = 0
		@_strobe = false

	keypressed: (key) =>
		btn = @_buttonMap[key]
		return unless btn
		@_buttonState[btn] = true
		true

	keyreleased: (key) =>
		btn = @_buttonMap[key]
		return unless btn
		@_buttonState[btn] = false
		true

	gamepadpressed: (joystick, button) =>
		-- TODO: multiple game pads
		btn = GAMEPADMAP[button]
		return unless btn
		@_buttonState[btn] = true
		true

	gamepadreleased: (joystick, button) =>
		-- TODO: multiple game pads
		btn = GAMEPADMAP[button]
		return unless btn
		@_buttonState[btn] = false
		true

	gamepadaxis: (joystick, axis, value) =>
		-- TODO: support right stick
		return unless axis == 'leftx' or axis == 'lefty'

		axisval = prevAxes[joystick]
		unless axisval
			axisval = {
				leftx: axis == leftx and value or 0
				lefty: axis == lefty and value or 0
			}
			prevAxes[joystick] = axisval

		return if math.abs(value) < GAMEPADNOISE

		switch axis
			when 'leftx'
				@_buttonState[LEFT] = value <= -GAMEPADTHRESHOLD
				@_buttonState[RIGHT] = value > GAMEPADTHRESHOLD
				axisval.leftx = value
				true

			when 'lefty'
				@_buttonState[UP] = value <= -GAMEPADTHRESHOLD
				@_buttonState[DOWN] = value > GAMEPADTHRESHOLD
				axisval.lefty = value
				true

	step: =>

	read: =>
		b = bor(band(@_data, 0xb0), 0x40)
		--b = 0x40
		return bor(@_buttonState[A] and 1 or 0, b) if @_strobe
		val = band(@_state, 0x01)
		@_state = rshift(bor(@_state, 0xff00), 1)
		bor(val, b)

	write: (val) =>
		@_data = val
		@_strobe = band(val, 0x01) == 0x01
		return if @_strobe
		@_state = 0
		for i = A, RIGHT
			continue if not @_buttonState[i] or @_buttonState[IMPOSSIBLE[i]]
			@_state = bor(@_state, lshift(1, i))
