ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')
import max, abs from math

(nes) ->
	mapper = require('Cart.Mapper')(nes)

	ppu = nes\getPPU!
	cart = nes\getCart!
	rom = cart\getPRGROM!
	ram = cart\getPRGRAM!
	chr = cart\getCHRROM! or cart\getCHRRAM!

	prgSize = cart\getPRGROMSize!
	chrSize = cart\getCHRROMSize! > 0 and cart\getCHRROMSize! or cart\getCHRRAMSize!

	irqEnabled = false
	irqCounter = 0
	irqLatch = 0
	reload = false

	lastA12 = 0
	lastA12fall = 0

	prgBanks = ffi.new('int[4]', 0x8000, 0xa000, prgSize - 0x4000, prgSize - 0x2000)
	chrBanks = ffi.new('int[8]', 0x0000, 0x0400, 0x0800, 0x0c00, 0x1000, 0x1400, 0x1800, 0x1c00)

	prgMap = 0
	bankSelect = 0
	bankMode = 0

	registers = {
		[0]: (val) ->
			bankSelect = band(val, 0x07)
			prgMap = band(rshift(val, 6), 0x01)
			bankMode = rshift(band(val, 0x80), 5)

		[1]: (val) ->
			if bankSelect > 5
				b = band(band(val, 0x3f) * 0x2000, prgSize - 1)
				prgBanks[band(bankSelect, 0x01)] = b
				return

			if bankSelect > 1
				b = band(val * 0x0400, chrSize - 1)
				chrBanks[bankSelect - (bankMode - 2)] = b
				return

			b = band(band(val, 0xfe) * 0x0400, chrSize - 1)
			bank = lshift(bankSelect, 1) + bankMode
			chrBanks[bank] = b
			chrBanks[bank + 1] = b + 0x0400

		[2]: (val) ->
			return if band(cart\getNTMirroring!, 0x04) == 0x04
			if band(val, 0x01) == 0
				mapper.nametables.switch2V!
			else
				mapper.nametables.switch2H!

		[3]: (val) -> -- RAM protect
		[4]: (val) -> irqLatch = val
		[5]: (val) ->
			irqCounter = 0
			reload = true
		[6]: (val) ->
			irqEnabled = false
			nes\getCPU!\irq_high!
		[7]: (val) ->
			irqEnabled = true
	}

	readPRG = {
		[0]: {
			[0]: (addr) -> ram[addr]               -- 6000-7fff
			[1]: (addr) -> rom[prgBanks[0] + addr] -- 8000-9fff
			[2]: (addr) -> rom[prgBanks[1] + addr] -- a000-bfff
			[3]: (addr) -> rom[prgBanks[2] + addr] -- c000-dfff
			[4]: (addr) -> rom[prgBanks[3] + addr] -- e000-ffff
		}

		[1]: {
			[0]: (addr) -> ram[addr]               -- 6000-7fff
			[1]: (addr) -> rom[prgBanks[2] + addr] -- 8000-9fff
			[2]: (addr) -> rom[prgBanks[1] + addr] -- a000-bfff
			[3]: (addr) -> rom[prgBanks[0] + addr] -- c000-dfff
			[4]: (addr) -> rom[prgBanks[3] + addr] -- e000-ffff
		}
	}

	writePRG = {
		[0]: (addr, val) -> ram[addr - 0x6000] = val
		[1]: (addr, val) ->
			reg = band(rshift(addr, 12), 0x06) + band(addr, 0x01)
			registers[reg](val)
	}

	_clockCounter = ->
		irqCounter = max(0, irqCounter - 1)
		irqCounter, reload = irqLatch, false if reload

		if irqCounter == 0
			nes\getCPU!\irq_low! if irqEnabled
			reload = true

	_a12watch = (a12, cycle) ->
		rise = false
		if a12 > lastA12
			rise = abs(cycle - lastA12fall) > 9
		elseif a12 < lastA12
			lastA12fall = cycle

		lastA12 = a12
		_clockCounter! if rise

	mapper.write = (addr, val) =>
		writePRG[rshift(addr, 15)](addr, val)
		nil

	mapper.read = (addr) =>
		bank = rshift(addr, 13) - 3
		readPRG[prgMap][bank](band(addr, 0x1fff))

	mapper.readCHR = (addr) =>
		bank = rshift(addr, 10)
		ppu\_updateA12(addr)
		chr[chrBanks[bank] + band(addr, 0x03ff)]

	readVRAM = mapper.readVRAM
	mapper.readVRAM = (addr) =>
		ppu\_updateA12(0)
		readVRAM(@, addr)

	nes\getPPU!\setA12Watcher(_a12watch)

	mapper
