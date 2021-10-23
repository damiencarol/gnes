ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')

(nes) ->
	mapper = require('Cart.Mapper')(nes)
	cart = nes\getCart!

	rom = cart\getPRGROM!
	banks = { [0]: 0, [1]: cart\getPRGROMSize! - 0x4000 }

	mapper.write = (addr, val) =>
		if addr >= 0x8000
			banks[0] = lshift(band(val, 0x0f), 14)

	mapper.read = (addr) =>
		bank = banks[band(rshift(addr, 14), rshift(addr, 15))]
		rom[bor(band(addr, 0x3fff), bank)]

	mapper
