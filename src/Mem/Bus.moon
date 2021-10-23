ffi = require('ffi')
import band, rshift from require('bit')
import min, max from math

selectIO = (addr) ->
	-- RAM:  0x0000-0x1fff -> 0
	-- PPU:  0x2000-0x3fff -> 1
	-- APU:  0x4000-0x401f -> 2
	-- CART: 0x4020-0xffff -> 3
	min(2, rshift(addr, 13)) + min(1, max(0, addr - 0x401f))

(mapper, ppu, apu) ->
	ram = ffi.new('uint8_t[?]', 0x0800)

	read = {
		[0]: (addr) -> ram[band(addr, 0x07ff)]
		[1]: (addr) -> ppu\read(band(addr, 0x0007))
		[2]: (addr) -> apu\read(band(addr, 0x001f))
		[3]: (addr) -> mapper\read(addr)
	}

	write = {
		[0]: (addr, value) -> ram[band(addr, 0x07ff)] = value
		[1]: (addr, value) -> ppu\write(band(addr, 0x0007), value)
		[2]: (addr, value) -> apu\write(band(addr, 0x001f), value)
		[3]: (addr, value) -> mapper\write(addr, value)
	}

	{
		read8: (addr) => read[selectIO(addr)](addr)

		write8: (addr, value) => write[selectIO(addr)](addr, value)

		read16: (addr) => @read8(addr) + @read8(addr + 1) * 0x100

		write16: (addr, value) =>
			@write8(addr, band(rshift(value, 8), 0xff))
			@write8(addr + 1, band(value, 0xff))
	}
