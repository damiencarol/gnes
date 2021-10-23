ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')
import min, max, abs from math

(nes) ->
	mapper = require('Cart.Mapper')(nes)

	cart = nes\getCart!
	rom = cart\getPRGROM!
	ram = cart\getPRGRAM!
	chr = cart\getCHRROM! or cart\getCHRRAM!

	prgSize = cart\getPRGROMSize!

	prgBanks = ffi.new('int[2]', 0x0000, prgSize - 0x4000)
	chrBanks = ffi.new('int[2]', 0x0000, 0x1000)

	prgBankMode = 0
	chrBankMode = 0

	shiftRegister = 0
	writeCount = 0
	mirrorMode = 0

	mirroring = {
		[0]: mapper.nametables.switch1L
		[1]: mapper.nametables.switch1H
		[2]: mapper.nametables.switch2V
		[3]: mapper.nametables.switch2H
	}

	switchPRG = {
		[0]: (bank) -> -- 32 KiB switchable
			addr = band(bank, 0xfe) * 0x4000
			prgBanks[0] = addr
			prgBanks[1] = addr + 0x4000

		[1]: (bank) -> -- 32 KiB switchable
			switchPRG[0](bank)

		[2]: (bank) ->
			prgBanks[0] = 0x0000 -- fixed 16 KiB @ 0x8000
			prgBanks[1] = bank * 0x4000 -- 16 KiB switchable @ 0xc000

		[3]: (bank) ->
			prgBanks[0] = bank * 0x4000 -- 16 KiB switchable @ 0x8000,
			prgBanks[1] = prgSize - 0x4000 -- fixed 16 KiB @ 0xc000
	}

	switchCHR = {
		[0]: (bank) ->
			bank = band(bank, 0xfe) * 0x1000
			chrBanks[0] = bank
			chrBanks[1] = bank + 0x1000

		[1]: (bank) ->
			chrBanks[0] = bank * 0x1000
	}

	registers = {
		[0]: (val) -> -- control, 8000-9fff
			prgBankMode = band(rshift(val, 2), 0x03)
			chrBankMode = band(rshift(val, 4), 0x01)
			mirror = band(val, 0x03)
			if mirror ~= mirrorMode
				mirrorMode = mirror
				mirroring[mirror]!

		[1]: (val) -> -- chr bank 0, a000-bfff
			switchCHR[chrBankMode](val)

		[2]: (val) -> -- chr bank 1, c000-dfff
			return if chrBankMode == 0 -- only in 2x4k mode
			chrBanks[1] = val * 0x1000

		[3]: (val) -> -- prg bank, e000-ffff
			bank = band(val, 0x0f)
			switchPRG[prgBankMode](band(val, 0x0f))
	}

	readPRG = {
		[0]: (addr) -> ram[addr]               -- 6000-7fff
		[1]: (addr) -> rom[prgBanks[0] + addr] -- 8000-bfff
		[2]: (addr) -> rom[prgBanks[1] + addr] -- c000-ffff
	}

	writePRG = {
		[0]: (addr, val) -> ram[addr - 0x6000] = val
		[1]: (addr, val) ->
			if band(val, 0x80) > 0
				writeCount, shiftRegister = 0, 0
				return

			writeCount += 1
			shiftRegister = bor(rshift(shiftRegister, 1), lshift(band(val, 0x01), 4))
			return if writeCount < 5

			reg = rshift(addr - 0x8000, 13)
			registers[reg](shiftRegister)
			writeCount, shiftRegister = 0, 0
	}

	mapper.write = (addr, val) =>
		writePRG[rshift(addr, 15)](addr, val)
		nil

	mapper.read = (addr) =>
		bank = rshift(addr, 14) - 1
		readPRG[bank](band(addr, 0x3fff))

	mapper.readCHR = (addr) =>
		bank = rshift(addr, 12)
		chr[chrBanks[bank] + band(addr, 0x0fff)]

	mapper
