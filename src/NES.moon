ffi = require('ffi')
import floor from math
import timer from love

export printf = (fmt, ...) -> print(fmt\format(...))

Cart = require('Cart')
Bus = require('Mem.Bus')
CPU = require('CPU')
PPU = require('PPU')
APU = require('APU')
Controller = require('Controller')

class NES
	PAL: 1662607
	NTSC: 1789773

	new: (rom, @_frameCallback) =>
		jit.off(@tick)

		@_screen = love.image.newImageData(SCREEN_WIDTH, SCREEN_HEIGHT, 'r8')
		@_cart = Cart(rom)
		@_isPAL = @_cart\getSystem! == 'PAL'
		@_freq = NES[@_cart\getSystem!]
		@_ppu = PPU(@)
		@_apu = APU(@)

		@_mapper = @_createMapper!
		@_ppu\getMem!\setMapper(@_mapper)
		@_bus = Bus(@_mapper, @_ppu, @_apu)

		@_cpu = CPU(@_bus, false)
		@_ctrl1 = Controller(@_apu, 0x4016, {
			a: 'x'
			b: 'c'
			start: 'return'
			select: 'space'
			left: 'left'
			right: 'right'
			up: 'up'
			down: 'down'
		})
		@_ctrl2 = Controller(@_apu, 0x4017)
		@_apu\setCPU(@_cpu)
		@_apu\setController(@_ctrl1, @_ctrl2)
		@_phase = 0
		@_frameCallback = ->

		@_frameStep = do
			stepP, stepA, stepC = @_ppu\step, @_apu\step, @_cpu\step
			frameStep = (steps) ->
				return if steps == 0
				stepP!
				stepC!
				stepA!
				frameStep(steps - 1)
			frameStep


	reset: (addr) =>
		@_ppu\reset!
		@_cpu\reset(addr, 0x24)
		@_phase = 0

	isPAL: => @_isPAL
	getMapper: => @_mapper
	getBus: => @_bus
	getCPU: => @_cpu
	getPPU: => @_ppu
	getAPU: => @_apu
	getController1: => @_ctrl1
	getController2: => @_ctrl2
	getCart: => @_cart
	getScreen: => @_screen

	setFrameCallback: (@_frameCallback) =>

	nextFrame: => @_frameCallback!

	keypressed: (key) => @_ctrl1\keypressed(key) or @_ctrl2\keypressed(key)

	keyreleased: (key) => @_ctrl1\keyreleased(key) or @_ctrl2\keyreleased(key)

	gamepadpressed: (joystick, button) =>
		@_ctrl1\gamepadpressed(joystick, button) or @_ctrl2\gamepadpressed(joystick, button)

	gamepadreleased: (joystick, button) =>
		@_ctrl1\gamepadreleased(joystick, button) or @_ctrl2\gamepadreleased(joystick, button)

	gamepadaxis: (joystick, axis, value) =>
		@_ctrl1\gamepadaxis(joystick, axis, value) or @_ctrl2\gamepadaxis(joystick, axis, value)

	tick: =>
		t = timer.getTime!
		@_ctrl1\step!
		@_ctrl2\step!
		@._frameStep(29781 - math.max(0, @_phase - 1))
		@_phase = (@_phase + 1) % 3
		timer.getTime! - t

	_createMapper: =>
		m = @_cart\getMapper!
		mapperFound, Mapper_t = pcall(require, "Cart.mappers.#{m}")
		error("Mapper not found: %d"\format(m)) unless mapperFound
		Mapper_t(@)
