ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')
import min, max from math

(nes) ->
	mapper = require('Cart.Mapper')(nes)
	cart = nes\getCart!

	rom, chr = cart\getPRGROM!, cart\getCHRROM!
	romSize = cart\getPRGROMSize!
	chrSize = cart\getCHRROMSize!
	prgBank = 0
	chrBank = 0

	mapper.write = (addr, val) =>
		if addr >= 0x8000
			prgBank = band(lshift(band(val, 0x03), 15), romSize - 1)
			chrBank = band(lshift(band(val, 0xf0), 9), chrSize - 1)

	mapper.read = (addr) =>
		rom[bor(band(addr, 0x7fff), prgBank)]

	mapper.readCHR = (addr) => chr[bor(band(addr, 0x1fff), chrBank)]

	mapper
