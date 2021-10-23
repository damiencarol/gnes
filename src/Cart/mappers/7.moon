ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')
import min, max from math

(nes) ->
	mapper = require('Cart.Mapper')(nes)
	cart = nes\getCart!
	rom = cart\getPRGROM!
	nametables = mapper.nametables
	nametables.switch1L!
	prgBank = 0

	mapper.write = (addr, val) =>
		if addr >= 0x8000
			prgBank = lshift(band(val, 0x07), 15)
			ntBank = lshift(band(val, 0x10), 6)
			nametables.setPages(ntBank)
			nametables.switch1L!

	mapper.read = (addr) =>
		rom[bor(band(addr, 0x7fff), prgBank)]

	mapper
