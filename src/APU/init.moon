ffi = require('ffi')
import bor, band, lshift, rshift from require('bit')
import min, max, floor from math

APU_cdef = [[
	struct {
		struct { //  0x4000 .. 0x4003
			uint8_t ctrl;
			uint8_t sweep;
			uint8_t timer;
			uint8_t counter;
		} pulse1;
		struct { // 0x4004 .. 0x4007
			uint8_t ctrl;
			uint8_t sweep;
			uint8_t timer;
			uint8_t counter;
		} pulse2;
		struct { // 0x4008 .. 0x400b
			uint8_t timer;
			uint8_t counter;
			uint8_t unused;
			uint8_t linear;
		} triangle;
		struct { // 0x400c .. 0x400f
			uint8_t timer;
			uint8_t counter;
			uint8_t envelope;
			uint8_t lfsr;
		} noise;
		struct { // 0x4010 .. 0x4013
			uint8_t timer;
			uint8_t reader;
			uint8_t buffer;
			uint8_t output;
		} dmc;
		uint8_t dma; // 0x4014 - dma
		uint8_t status; // 0x4015
		uint8_t ctrl1;  // 0x4016 - forwarded to controllers
		uint8_t framecounter; // 0x4017 - only bits 6-7

		int _oddClock;
	}
]]

LENGTHS = {
	[0]: 10
	254
	20
	2
	40
	4
	80
	6
	160
	8
	60
	10
	14
	12
	26
	14
	12
	16
	24
	18
	48
	20
	96
	22
	192
	24
	72
	26
	16
	28
	32
	30
}

PulseChannel = (regs) ->
	counter, timer = 0, 0
	halted = false

	{
		setLength: (l) =>
			counter = l

		getCounter: => counter

		setHalt: (val) =>
			halted = val

		clock: =>
			return if halted
			if counter > 0
				counter -= 1
				if counter == 0
					nil -- TODO
	}

TriangleChannel = -> {
	clock: =>
}

NoiseChannel = -> {
	clock: =>
}

DMC = -> {
	clock: =>
}

(system) ->
	MODE1 = 14915 * 2
	MODE2 = 18642 * 2

	cpu = nil
	ctrl1, ctrl2 = nil, nil
	ppu = system\getPPU!

	counterMode = 0
	irqEnabled = false
	stepMode = nil
	step = 0
	frameCounter = 0
	frameIRQ = false
	resetTimer = false

	pulse1, pulse2 = nil, nil
	triangle = nil
	noise = nil

	SEQUENCER = {
		[0]: {
			=>
			=>
				@_stepLength!
				--@_stepSweep!
			=>
			=>
				@_stepLength!
				--@_stepSweep!
		}

		[1]: {
			=>
			=>
			=>
			=>
			=>
		}
	}

	readReg = {
		[0x00]: => 0
		[0x01]: => 0
		[0x02]: => 0
		[0x03]: => 0
		[0x04]: => 0
		[0x05]: => 0
		[0x06]: => 0
		[0x07]: => 0
		[0x08]: => 0
		[0x09]: => 0
		[0x0a]: => 0
		[0x0b]: => 0
		[0x0c]: => 0
		[0x0d]: => 0
		[0x0e]: => 0
		[0x0f]: => 0
		[0x10]: => 0
		[0x11]: => 0
		[0x12]: => 0
		[0x13]: => 0
		[0x14]: => 0
		[0x15]: =>
			cpu\irq_high! if frameIRQ
			status = @status

			@_setFrameIRQ(false)
			p1c = min(1, pulse1\getCounter!)
			p2c = min(1, pulse2\getCounter!)
			status = band(status, 0xfc) + p1c + lshift(p2c, 1)
			status

		[0x16]: =>
			ctrl1\read!

		[0x17]: =>
			ctrl2\read!

		[0x18]: => 0
		[0x19]: => 0
		[0x1a]: => 0
		[0x1b]: => 0
		[0x1c]: => 0
		[0x1d]: => 0
		[0x1e]: => 0
		[0x1f]: => 0
	}

	writeReg = {
		[0x00]: (val) =>
			pulse1\setHalt(band(val, 0x20) > 0)

		[0x01]: (val) =>
		[0x02]: (val) =>
		[0x03]: (val) =>
			enabled = band(@status, 0x01)
			pulse1\setLength(LENGTHS[rshift(val, 3)] * enabled)

		[0x04]: (val) =>
			pulse2\setHalt(band(val, 0x20) > 0)

		[0x05]: (val) =>
		[0x06]: (val) =>
		[0x07]: (val) =>
			enabled = band(rshift(@status, 1), 0x01)
			pulse2\setLength(LENGTHS[rshift(val, 3)] * enabled)

		[0x08]: (val) =>
		[0x09]: (val) =>
		[0x0a]: (val) =>
		[0x0b]: (val) =>
		[0x0c]: (val) =>
		[0x0d]: (val) =>
		[0x0e]: (val) =>
		[0x0f]: (val) =>
		[0x10]: (val) =>
		[0x11]: (val) =>
		[0x12]: (val) =>
		[0x13]: (val) =>
		[0x14]: (val) => ppu\dma(val)
		[0x15]: (val) =>
			@status = val
			pulse1\setLength(0) if band(val, 0x01) == 0
			pulse2\setLength(0) if band(val, 0x02) == 0

		[0x16]: (val) =>
			@ctrl1 = val
			ctrl1\write(val)
			ctrl2\write(val)

		[0x17]: (val) =>
			@framecounter = val
			counterMode = rshift(band(val, 0x80), 7)
			stepMode = counterMode == 0 and @_stepMode0 or @_stepMode1
			irqEnabled = band(val, 0x40) == 0
			unless irqEnabled
				cpu\irq_high! if frameIRQ
				@_setFrameIRQ(false)
			resetTimer = true

		[0x18]: (val) =>
		[0x19]: (val) =>
		[0x1a]: (val) =>
		[0x1b]: (val) =>
		[0x1c]: (val) =>
		[0x1d]: (val) =>
		[0x1e]: (val) =>
		[0x1f]: (val) =>
	}

	ffi.metatype(ffi.typeof(APU_cdef), {
		__new: =>
			apu = ffi.new(@)
			stepMode = apu._stepMode0
			pulse1 = PulseChannel(apu.pulse1)
			pulse2 = PulseChannel(apu.pulse2)
			triangle = TriangleChannel!
			noise = NoiseChannel!
			apu

		__index: {
			setCPU: (c) => cpu = c
			setController: (j1, j2) => ctrl1, ctrl2 = j1, j2

			reset: => -- TODO
			step: =>
				stepMode(@)
				@_oddClock = band(@_oddClock + 1, 0x01)

			read: (reg) => readReg[reg](@)

			write: (reg, val) => writeReg[reg](@, val)

			_setFrameIRQ: (val) =>
				frameIRQ = val
				if val
					@status = bor(@status, 0x40)
				else
					@status = band(@status, 0xbf)

			_updateCounter: (length) =>
				frameCounter += 1
				if resetTimer and @_oddClock == 1
					if band(@framecounter, 0x80) > 0
						@_stepLength!
					frameCounter = 0
					resetTimer = false
				frameCounter %= length
				s = math.floor(frameCounter / 7457)
				if s ~= step and s > 0
					step = s
					return true

			_stepMode0: =>
				if @_updateCounter(MODE1 + 3)
					SEQUENCER[0][step](@)

				if irqEnabled
					@_setFrameIRQ(true) if frameCounter > MODE1 - 1
					cpu\irq_low! if frameIRQ

			_stepMode1: =>
				if @_updateCounter(MODE2 + 3)
					SEQUENCER[1][step](@)

			_stepLength: =>
				pulse1\clock!
				pulse2\clock!
		}
	})!

