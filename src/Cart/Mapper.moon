ffi = require('ffi')
import band from require('bit')

(nes) ->
	cart = nes\getCart!
	vram = nes\getPPU!\getMem!\getVRAM!
	nametables = require('Cart.util').NTSelector(cart)
	selectNT = nametables.selectNT

	with cart
		rom = \getPRGROM!
		chr = \getCHRROM! or \getCHRRAM!

		-- FIXME: rom size must be power of 2
		ROMMASK = \getPRGROMSize! - 1

		read = (addr) => rom[band(addr, ROMMASK)]
		write = (addr, value) =>

		readVRAM = (addr) => vram[selectNT(addr) + band(addr, 0x3ff)]
		writeVRAM = (addr, value) => vram[selectNT(addr) + band(addr, 0x3ff)] = value

		readCHR = do
			CHRMASK = (\getCHRRAM! and \getCHRRAMSize! or \getCHRROMSize!) - 1
			(addr) => chr[band(addr, CHRMASK)]

		writeCHR = do
			if \getCHRRAM!
				CHRMASK = \getCHRRAMSize! - 1
				(addr, val) => chr[band(addr, CHRMASK)] = val
			else
				(addr, val) =>

		return {
			:read
			:write
			:readCHR
			:writeCHR
			:readVRAM
			:writeVRAM
			:nametables
		}
