ffi = require('ffi')
import band, rshift, bxor from require('bit')
import min, max from math

PALMAP = do
	p = ffi.new('int8_t[32]')
	p[i] = i for i = 0, 31
	p[0x10] = p[0x00]
	p[0x14] = p[0x04]
	p[0x18] = p[0x08]
	p[0x1c] = p[0x0c]
	p

->
	vram = ffi.new('uint8_t[?]', 0x0800)
	palette = ffi.new('uint8_t[?]', 0x0020)
	mapper = nil

	setMapper = (m) => mapper = m

	selectIO = (addr) ->
		-- CHR: 0x0000-0x1fff -> 0
		-- VRM: 0x2000-0x3eff -> 1
		-- PAL: 0x3f00-0x3fff -> 2
		rshift(addr, 13) + max(0, min(1, addr - 0x3eff))

	readCHR = (addr) -> mapper\readCHR(addr)
	readVRAM = (addr) -> mapper\readVRAM(addr)
	readPAL = (addr) -> palette[PALMAP[band(addr, 0x1f)]]

	writeCHR = (addr, value) -> mapper\writeCHR(addr, value)
	writeVRAM = (addr, value) -> mapper\writeVRAM(addr, value)
	writePAL = (addr, value) -> palette[PALMAP[band(addr, 0x1f)]] = value

	read = setmetatable({
		[0]: readCHR
		[1]: readVRAM
		[2]: readPAL
	}, {
		__index: (k) => (addr) -> error("BUG: read from %04x: no reader at %d"\format(addr, k))
	})

	write = setmetatable({
		[0]: writeCHR
		[1]: writeVRAM
		[2]: writePAL
	}, {
		__index: (k) => (addr) -> error("BUG: write to %04x: no writer at %d"\format(addr, k))
	})

	{
		:setMapper
		:readCHR
		:readVRAM
		:readPAL
		:writeCHR
		:writeVRAM
		:writePAL
		getVRAM: -> vram

		read: (addr) -> read[selectIO(addr)](addr)
		write: (addr, value) -> write[selectIO(addr)](addr, value)
	}
