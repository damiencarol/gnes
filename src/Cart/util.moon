ffi = require('ffi')
import band, rshift from require('bit')

NTSelector = (cart) ->
	NTLO1, NTHI1 = 0x0000, 0x0400
	NTLO2, NTHI2 = NTLO1, NTHI1

	-- 8 nametable slots instead of 4 saves one band on access
	nt = ffi.new('int[8]', NTLO1, NTLO1, NTHI1, NTHI1, NTLO1, NTLO1, NTHI1, NTHI1)
	nt[1], nt[2], nt[5], nt[6] = nt[3], nt[0], nt[3], nt[0] if band(cart\getNTMirroring!, 0x01) == 0x01

	{
		selectNT: (addr) -> nt[rshift(addr, 10) - 8]

		setPages: (lo1, hi1 = lo1, lo2 = lo1, hi2 = hi1) ->
			NTLO1, NTHI1 = lo1, hi1
			NTLO2, NTHI2 = lo2, hi2

		switch1L: ->
			nt[0], nt[1], nt[2], nt[3] = NTLO1, NTLO1, NTLO1, NTLO1
			nt[4], nt[5], nt[6], nt[7] = NTLO1, NTLO1, NTLO1, NTLO1

		switch1H: ->
			nt[0], nt[1], nt[2], nt[3] = NTHI1, NTHI1, NTHI1, NTHI1
			nt[4], nt[5], nt[6], nt[7] = NTHI1, NTHI1, NTHI1, NTHI1

		switch2H: ->
			nt[0], nt[1], nt[2], nt[3] = NTLO1, NTLO1, NTHI1, NTHI1
			nt[4], nt[5], nt[6], nt[7] = NTLO1, NTLO1, NTHI1, NTHI1

		switch2V: ->
			nt[0], nt[1], nt[2], nt[3] = NTLO1, NTHI1, NTLO1, NTHI1
			nt[4], nt[5], nt[6], nt[7] = NTLO1, NTHI1, NTLO1, NTHI1

		switch4: ->
			nt[0], nt[1], nt[2], nt[3] = NTLO1, NTLO2, NTHI1, NTHI2
			nt[4], nt[5], nt[6], nt[7] = NTLO1, NTLO2, NTHI1, NTHI2
	}

{
	:NTSelector
}
