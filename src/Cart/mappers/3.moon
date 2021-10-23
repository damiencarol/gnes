ffi = require('ffi')
import band, bor, lshift, rshift from require('bit')

(nes) ->
	mapper = require('Cart.Mapper')(nes)
	cart = nes\getCart!

	chrBank = 0
	maxBank = rshift(cart\getCHRROMSize!, 13) - 1
	chr = cart\getCHRROM!

	mapper.write = (addr, val) =>
		return unless addr >= 0x8000
		chrBank = lshift(band(val, maxBank), 13)

	mapper.readCHR = (addr) => chr[bor(band(addr, 0x1fff), chrBank)]

	mapper
