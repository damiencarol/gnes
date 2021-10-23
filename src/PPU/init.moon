ffi = require('ffi')
Mem = require('Mem.PPUMem')

import band, bor, rshift, lshift from require('bit')

PPU_cdef = [[
	struct {
		uint8_t ctrl;
		uint8_t mask;
		uint8_t status;
		uint8_t OAMaddr, OAM2addr;
		uint8_t data;

		uint16_t vramAddr, tempAddr;
		uint8_t fineX;

		uint8_t oam[256];
		uint8_t oam2[32];
		uint8_t sprites[64];

		uint16_t bgTable;
		uint16_t sprTable;

		int bgOn, spritesOn, renderingOn;
		int clipBG, clipSpr;

		uint16_t x, y;
		uint8_t dataBuffer;

		uint8_t bgTile;
		uint8_t bgAttr[3];
		uint16_t bgPat[3];
		uint8_t bgPatLo;

		int8_t sprSize;
		int8_t numSprites, numNextSprites;
		int8_t sprFlipH, sprFlipV;
		uint16_t sprAddr;
		int zeroHit;
		int spr0Active[2];
		int8_t oddFrame;

		uint8_t *frameBuffer;

		int cycleCount;
		int frameCount;
		int lastStatusRead;
		int nmiFired;
		int dmaAddr;
		int dmaCount;
		uint8_t dmaData;
		int writePhase;
	}
]]

RASTERLEN = 341

REGW = 1
REGR = 2
IRQ = 4

LOG_FLAGS = 0--xffff--REGW + IRQ

(nes) ->
	STATES = require("PPU.#{nes\getCart!\getSystem!}.states")
	pal = nes\isPAL!
	LINES = pal and 313 or 262
	-- emphasis bits
	RBIT = pal and 0x20 or 0x40
	GBIT = pal and 0x40 or 0x20

	mem = Mem!

	screen = ffi.cast('uint8_t*', nes\getScreen!\getFFIPointer!)
	fb = ffi.new('uint8_t[?]', SCREEN_WIDTH * SCREEN_HEIGHT)

	nmiEnabled = false
	addrIncr = 0x01
	greyscale = false
	eR, eG, eB = false, false, false -- emphasis

	warmup = true

	writeReg = {
		[0]: (val) =>
			--@log(REGW, "%02x > $2000", val)
			return if warmup
			do
				v = lshift(band(val, 0x03), 10)
				@tempAddr = bor(band(@tempAddr, 0x73ff), v)

			@ctrl = val
			enableNMI = band(val, 0x80) > 0
			-- enabling NMI during vblank triggers NMI
			if enableNMI and not nmiEnabled and band(@status, 0x80) > 0
				@nmiFired = 0
			nmiEnabled = enableNMI

			largeSpr   = rshift(band(val, 0x20), 5)
			@bgTable   = lshift(band(val, 0x10), 8)
			@sprTable  = rshift(band(val, 0x08), 3) * (1 - largeSpr)
			addrIncr   = rshift(band(val, 0x04), 2) * 0x1f + 0x01
			@sprSize   = 8 + largeSpr * 8
			-- TODO 0x40 - master/slave mode

		[1]: (val) =>
			--@log(REGW, "%02x > $2001", val)

			@mask = val
			eB =        band(val, 0x80) > 0
			eG =        band(val, GBIT) > 0
			eR =        band(val, RBIT) > 0
			greyscale = band(val, 0x01) > 0
			@bgOn = band(rshift(val, 3), 0x01)
			@spritesOn = band(rshift(val, 4), 0x01)
			@renderingOn = bor(@spritesOn, @bgOn)
			-- with rendering disabled, the clip boundary is outside the screen
			-- otherwise it's at 0 or 8 depending on clip flags
			@clipSpr = (1 - @spritesOn) * 512 + (0x08 - band(val, 0x04) * 2)
			@clipBG = (1 - @bgOn) * 512 + (0x08 - band(val, 0x02) * 4)

		[2]: (val) =>
			--@log(REGW, "%02x > $2002", val)

		[3]: (val) =>
			--@log(REGW, "%02x > $2003", val)
			@OAMaddr = val

		[4]: (val) =>
			--@log(REGW, "%02x > $2004 (%02x)", val, @OAMaddr)
			val = band(val, 0xe3) if band(@OAMaddr, 0x03) == 0x02
			@oam[@OAMaddr] = val
			@OAMaddr += 1

		[5]: (val) =>
			--@log(REGW, "%02x > $2005", val)
			if @writePhase == 0
				do
					v = band(rshift(val, 3), 0x1f)
					@tempAddr = bor(band(@tempAddr, 0x7fe0), v)
					@fineX = band(val, 0x07)
			else
				do
					v1 = lshift(band(val, 0x07), 12)
					v2 = lshift(band(val, 0xf8), 2)
					@tempAddr = bor(band(@tempAddr, 0x0c1f), v1, v2)
			@writePhase = band(@writePhase + 1, 0x01)

		[6]: (val) =>
			--@log(REGW, "%02x > $2006", val)
			if @writePhase == 0
				v = lshift(band(val, 0x3f), 8)
				@tempAddr = bor(band(@tempAddr, 0xff), v)
			else
				@tempAddr = bor(band(@tempAddr, 0xff00), val)
				@vramAddr = @tempAddr
				@_updateA12(@vramAddr)
			@writePhase = band(@writePhase + 1, 0x01)

		[7]: (val) =>
			--@log(REGW, "%02x > $2007", val)
			@data = val
			mem.write(@vramAddr, val)
			@vramAddr = band(@vramAddr + addrIncr, 0x3fff)
			@_updateA12(@vramAddr)
	}

	readReg = {
		[0]: => 0
		[1]: => 0
		[2]: =>
			--@log(REGR, "$2002 > %02x", @status)
			@lastStatusRead = @cycleCount
			res = @status
			@status = band(res, 0x7f) -- clear vblank
			@writePhase = 0
			res

		[3]: => 0
		[4]: =>
			val = @oam[@OAMaddr]
			--@log(REGR, "$2004 (%02x) > %02x", @OAMaddr, val)
			val

		[5]: => 0
		[6]: => 0
		[7]: =>
			addr, @data = @vramAddr, @dataBuffer
			@vramAddr = band(addr + addrIncr, 0x3fff)
			@_updateA12(@vramAddr)
			@dataBuffer = mem.read(addr)
			if addr > 0x3eff -- palette
				@data = @dataBuffer
				@dataBuffer = mem.readPAL(0x2f00 + band(addr, 0x1f))
			--@log(REGR, "$2007 > %02x", @data)
			@data
	}

	state = STATES[0]
	a12default = ->
	a12watch = a12default

	ffi.metatype(ffi.typeof(PPU_cdef), {
		__new: =>
			ppu = ffi.new(@)
			ppu

		__index: {
			log: (grp, fmt, ...) =>
				return if band(LOG_FLAGS, grp) == 0
				io.write("%5d %04x %5d (%3d, %3d) | %s\n"\format(@frameCount, nes\getCPU!.state.PC, @cycleCount, @x, @y, fmt\format(...)))

			step: =>
				@_serviceDMA! if @dmaCount > 0
				@_tick(3)

			reset: =>
				-- FIXME: something is missing here
				ffi.fill(@, ffi.sizeof(@), 0)
				@frameBuffer = fb
				nmiEnabled = false
				addrIncr = 1
				state = STATES[0]
				warmup = true

			getMem: => mem
			getState: => @x, @y -- TODO: remove

			present: =>
				ffi.copy(screen, @frameBuffer, SCREEN_WIDTH * SCREEN_HEIGHT)
				nes\nextFrame!

			nmi: =>
				if nmiEnabled and @dmaCount == 0
					--@log(IRQ, "NMI")
					nes\getCPU!\nmi!

			read: (reg) => readReg[reg](@)

			write: (reg, val) => writeReg[reg](@, val)

			dma: (addr) =>
				@dmaAddr = lshift(addr, 8)
				latency = bor(@oddFrame, @renderingOn)
				@dmaCount = 513 + latency
				--@log(IRQ, "DMA $%04x (%d cycles)", @dmaAddr, @dmaCount)
				nes\getCPU!\wait(513 + latency)

			setA12Watcher: (watcher) => a12watch = watcher or a12default

			_updateA12: (addr) =>
				a12watch(band(rshift(addr, 12), 0x01), @cycleCount)

			_tick: (n) =>
				return if n == 0

				-- next pixel
				state[@x](@, mem)
				@cycleCount += 1
				@x += 1
				return @_tick(n - 1) if @x < RASTERLEN

				-- next scanline
				@x, @y = 0, (@y + 1) % LINES
				state = STATES[@y]
				return @_tick(n - 1) if @y > 0

				-- next frame
				warmup = false
				@frameCount += 1
				@oddFrame = band(@oddFrame + 1, 0x01)
				@cycleCount = 0
				@_tick(n - 1)

			_serviceDMA: =>
				@dmaCount -= 1
				if @dmaCount < 512
					if band(@dmaCount, 0x01) == 1
						@dmaData = nes\getBus!\read8(@dmaAddr + 255 - rshift(@dmaCount, 1))
					else
						writeReg[0x04](@, @dmaData)
		}
	})!
