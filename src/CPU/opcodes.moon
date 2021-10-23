(cpu, state, mem, BCD = true) ->
	import bor, band, bnot, bxor, lshift, rshift from require('bit')

	tou8, tos8, tou16 = do
		tmp = require('ffi').new("
			struct {
				uint8_t  u8;
				int8_t   s8;
				uint16_t u16;
			}
		")

		u8 = =>
			tmp.u8 = @
			tmp.u8
		s8 = =>
			tmp.s8 = @
			tmp.s8
		u16 = =>
			tmp.u16 = @
			tmp.u16

		u8, s8, u16

	read8 = mem\read8
	read16 = mem\read16
	accum = -> state.A
	write8 = mem\write8
	writea = (addr, v) -> state.A = v
	penalty = (base, addr) -> band(rshift(bxor(base, addr), 8), 0x01)

	-- addressing modes
	imp = =>
	imm = =>
		base = @PC
		@PC += 1
		base

	zp =  =>
		base = mem\read8(@PC)
		@PC += 1
		base

	zpx = =>
		base = mem\read8(@PC)
		@PC += 1
		band(base + @X, 0xff)

	zpy = =>
		base = mem\read8(@PC)
		@PC += 1
		band(base + @Y, 0xff)

	ab =  =>
		base = read16(@PC)
		@PC += 2
		base

	abx = =>
		base = read16(@PC)
		@PC += 2
		band(base + @X, 0xffff)

	aby = =>
		base = read16(@PC)
		@PC += 2
		band(base + @Y, 0xffff)

	rel = =>
		base = mem\read8(@PC)
		@PC += 1
		tos8(base)

	abxp = =>
		base = mem\read16(@PC)
		@PC += 2
		addr = band(base + @X, 0xffff)
		@_cycles += penalty(base, addr)
		addr

	abyp = =>
		base = mem\read16(@PC)
		@PC += 2
		addr = band(base + @Y, 0xffff)
		@_cycles += penalty(base, addr)
		addr

	ind = =>
		base = mem\read16(@PC)
		@PC += 2
		mem\read8(base) + 0x100 * mem\read8(band(base, 0xff00) + band(base + 1, 0x00ff))

	indx = =>
		b1 = band(mem\read8(@PC) + @X, 0xff)
		@PC += 1
		mem\read8(b1) + mem\read8(band(b1 + 1, 0xff)) * 0x100

	indy = =>
		b1 = mem\read8(@PC)
		@PC += 1
		band((mem\read8(b1) + mem\read8(band(b1 + 1, 0xff)) * 0x100 + @Y), 0xffff)

	indyp = =>
		b1 = mem\read8(@PC)
		@PC += 1
		base = mem\read8(b1) + mem\read8(band(b1 + 1, 0xff)) * 0x100
		addr = band((base + @Y), 0xffff)
		@_cycles += penalty(base, addr)
		addr

	-- instructions

	JAM = => error("CPU JAM @%0x4"\format(@PC))
	CLC = => cpu\setC(0x00)
	CLD = => cpu\setD(0x00)
	CLV = => cpu\setV(0x00)
	SEC = => cpu\setC(0x01)
	SED = => cpu\setD(0x08)
	PHA = => cpu\push8(@A)
	PHP = => cpu\push8(bor(@P, 0x10))
	TAX = => @X = cpu\updateZN(@A)
	TAY = => @Y = cpu\updateZN(@A)
	TXA = => @A = cpu\updateZN(@X)
	TYA = => @A = cpu\updateZN(@Y)
	TSX = => @X = cpu\updateZN(@SP)
	TXS = => @SP = @X
	INX = => @X = cpu\updateZN(band(@X + 1, 0xff))
	DEX = => @X = cpu\updateZN(band(@X - 1, 0xff))
	INY = => @Y = cpu\updateZN(band(@Y + 1, 0xff))
	DEY = => @Y = cpu\updateZN(band(@Y - 1, 0xff))
	PLA = => @A = cpu\updateZN(cpu\pop8!)
	RTS = => @PC = cpu\pop16! + 1
	ORA = (am) -> => @A = cpu\updateZN( bor(@A, read8(am(@))))
	AND = (am) -> => @A = cpu\updateZN(band(@A, read8(am(@))))
	EOR = (am) -> => @A = cpu\updateZN(bxor(@A, read8(am(@))))
	LDA = (am) -> => @A = cpu\updateZN(read8(am(@)))
	LDX = (am) -> => @X = cpu\updateZN(read8(am(@)))
	LDY = (am) -> => @Y = cpu\updateZN(read8(am(@)))
	SAX = (am) -> => write8(am(@), band(@A, @X))
	STA = (am) -> => write8(am(@), @A)
	STX = (am) -> => write8(am(@), @X)
	STY = (am) -> => write8(am(@), @Y)

	BRK = =>
		cpu\push16(@PC + 1)
		cpu\push8(bor(@P, 0x30))
		cpu\setI(0x04)
		@PC = read16(0xfffe)

	NOP = (am) ->
		=>
			am(@)
			nil

	SEI = => cpu\setI(0x04)
	PLP = => @P = bor(band(cpu\pop8!, 0xef), 0x20)

	RTI = =>
		@P, @PC = bor(band(cpu\pop8!, 0xef), 0x20), cpu\pop16!
		cpu\_pollInterrupts!

	CLI = =>
		cpu\setI(0x00)
		@_delay_irq += 1

	JSR = =>
		base = read16(@PC)
		@PC += 2
		cpu\push16(band(@PC - 1, 0xffff))
		@PC = base

	ASL = (am, r, w) ->
		=>
			addr = am(@)
			v = lshift(r(addr), 1)
			cpu\setC(rshift(v, 8))
			a = cpu\updateZN(band(v, 0xff))
			w(addr, a)

	SLO = (am, r, w) ->
		=>
			addr = am(@)
			b = lshift(r(addr), 1)
			w(addr, b)
			v = bor(@A, b)
			cpu\setC(rshift(b, 8))
			@A = cpu\updateZN(band(v, 0xff))

	BIT = (am) ->
		=>
			v = read8(am(@))
			cpu\updateZ(band(@A, v))
			@P = bor(band(@P, 0x3f), band(v, 0xc0))

	ROL = (am, r, w) ->
		=>
			addr = am(@)
			a = r(addr)
			v = bor(lshift(a, 1), band(@P, 0x01))
			cpu\setC(rshift(v, 8))
			a = band(v, 0xff)
			w(addr, a)
			cpu\updateZN(a)

	RLA = (am, r, w) ->
		=>
			addr = am(@)
			a = r(addr)
			v = bor(a * 2, band(@P, 0x01))
			w(addr, v)

			cpu\setC(rshift(v, 8))
			a = band(band(@A, v), 0xff)
			@A = cpu\updateZN(a)

	LSR = (am, r, w) ->
		=>
			addr = am(@)
			a = r(addr)
			v = rshift(a, 1)
			cpu\setC(band(a, 0x01))
			w(addr, v)
			cpu\updateZN(v)

	SRE = (am, r, w) ->
		=>
			addr = am(@)
			a = r(addr)
			v = rshift(a, 1)
			w(addr, v)
			cpu\setC(band(a, 0x01))
			v = bxor(v, @A)
			@A = cpu\updateZN(v)

	ROR = (am, r, w) ->
		=>
			addr = am(@)
			a = r(addr)
			v = rshift(a, 1) + band(@P, 0x01) * 0x80
			cpu\setC(band(a, 0x01))
			a = band(v, 0xff)
			w(addr, a)
			cpu\updateZN(a)

	adc = if BCD
		import min, max from math
		(a, m, carry, bcd) ->
			res = a + m + carry
			v = rshift(band(bxor(res, m), band(bxor(res, a), 0x80)), 1)
			-- TODO: N bit always 1 in BCD mode
			-- TODO: compute Z bit before BCD

			res += bcd * 0x06 * max(0x00, min(0x01, (band(a, 0x0f) + band(m, 0x0f) + carry) - 0x09))
			res += bcd * 0x60 * max(0x00, min(0x01, res - 0x99))

			c = band(rshift(res, 8), 0x01)
			band(res, 0xff), v, c
	else
		(a, m, carry) ->
			res = a + m + carry
			v = rshift(band(bxor(res, m), band(bxor(res, a), 0x80)), 1)
			c = band(rshift(res, 8), 0x01)
			band(res, 0xff), v, c

	ADC = (am) ->
		=>
			m = read8(am(@))
			a, v, c = adc(@A, m, band(@P, 0x01), rshift(band(@P, 0x08), 3))
			cpu\setV(v)
			cpu\setC(c)
			@A = cpu\updateZN(a)

	sbc = if BCD
		import min, max from math
		(a, m, carry, bcd) ->
			res = band(a - m - (1 - carry), 0xffff)
			v = rshift(band(bxor(m, a), band(bxor(res, a), 0x80)), 1)
			-- TODO: N bit always 1 in BCD mode
			-- TODO: compute Z bit before BCD

			res -= bcd * 0x06 * max(0x00, min(0x01, band(m, 0x0f) - band(a, 0x0f) + (1 - carry)))
			res -= bcd * 0x60 * max(0x00, min(0x01, res - 0x99))

			c = 1 - band(rshift(res, 8), 1)
			band(res, 0xff), v, c
	else
		(a, m, carry) ->
			res = band(a - m - (1 - carry), 0xffff)
			v = rshift(band(bxor(m, a), band(bxor(res, a), 0x80)), 1)
			c = 1 - band(rshift(res, 8), 1)
			band(res, 0xff), v, c

	SBC = (am) ->
		=>
			m = read8(am(@))
			a, v, c = sbc(@A, m, band(@P, 0x01), rshift(band(@P, 0x08), 3))
			cpu\setV(v)
			cpu\setC(c)
			@A = cpu\updateZN(a)

	CMP = (am) ->
		import min, max from math
		=>
			val = @A - read8(am(@))
			cpu\setC(max(0x00, min(val + 1, 0x01)))
			cpu\updateZN(val)

	CPX = (am) ->
		import min, max from math
		=>
			val = @X - read8(am(@))
			cpu\setC(max(0x00, min(val + 1, 0x01)))
			cpu\updateZN(val)

	CPY = (am) ->
		import min, max from math
		=>
			val = @Y - read8(am(@))
			cpu\setC(max(0x00, min(val + 1, 0x01)))
			cpu\updateZN(val)

	DEC = (am) ->
		=>
			addr = am(@)
			v = cpu\updateZN(band(read8(addr) - 1, 0xff))
			write8(addr, v)

	INC = (am) ->
		=>
			addr = am(@)
			v = cpu\updateZN(band(read8(addr) + 1, 0xff))
			write8(addr, v)

	trap = CPU_TEST and => error("trapped: %04x @ %d"\format(@PC - 1, tonumber(@_instCounter)))

	BRANCH = (flag, ifset) ->
		if CPU_TEST
			=>
				base = rel(@)
				return unless cpu\testStatus(flag) == ifset
				trap(@) if base == -2
				addr = band(@PC + base, 0xffff)
				@_cycles += 1 + penalty(@PC, addr)
				@PC = addr
		else
			=>
				base = rel(@)
				return unless cpu\testStatus(flag) == ifset
				addr = band(@PC + base, 0xffff)
				@_cycles += 1 + penalty(@PC, addr)
				@PC = addr

	JMP = (am) ->
		if CPU_TEST
			=>
				addr = am(@)
				if addr == @PC - 3
					if addr == 0x3469
						CPU_TEST!
					else
						trap(@)
				@PC = addr
		else
			=> @PC = am(@)

	LAX = (am) ->
		=>
			@X = cpu\updateZN(read8(am(@)))
			@A = @X

	DCP = (am) ->
		import min, max from math
		=>
			addr = am(@)
			v = band(read8(addr) - 1, 0xff)
			write8(addr, v)
			cmp = @A - v
			cpu\setC(max(0x00, min(cmp + 1, 0x01)))
			cpu\updateZN(cmp)

	ISB = (am) ->
		=>
			addr = am(@)
			m = band(read8(addr) + 1, 0xff)
			write8(addr, m)
			a, v, c = sbc(@A, m, band(@P, 0x01), rshift(band(@P, 0x08), 3))
			cpu\setV(v)
			cpu\setC(c)
			@A = cpu\updateZN(a)

	RRA = (am) ->
		=>
			addr = am(@)
			m = read8(addr)
			r = rshift(m, 1) + band(@P, 0x01) * 0x80
			c = band(m, 0x01)
			a = band(r, 0xff)
			write8(addr, a)

			a, v, c = adc(@A, a, c, rshift(band(@P, 0x08), 3))
			cpu\setV(v)
			cpu\setC(c)
			@A = cpu\updateZN(a)

	opcodes = {
		-- size, cycles, invalid, instruction
		[0x00]: { 1, 7, false, BRK }
		[0x01]: { 2, 6, false, ORA(indx) }
		[0x02]: { 1, 2,  true, JAM }
		[0x03]: { 2, 8,  true, SLO(indx, read8, write8) }
		[0x04]: { 2, 3,  true, NOP(zp) }
		[0x05]: { 2, 3, false, ORA(zp) }
		[0x06]: { 2, 5, false, ASL(zp, read8, write8) }
		[0x07]: { 2, 5,  true, SLO(zp, read8, write8) }
		[0x08]: { 1, 3, false, PHP }
		[0x09]: { 2, 2, false, ORA(imm) }
		[0x0a]: { 1, 2, false, ASL(accum, accum, writea) }
		-- TODO: ANC imm
		[0x0c]: { 3, 4,  true, NOP(ab) }
		[0x0d]: { 3, 4, false, ORA(ab) }
		[0x0e]: { 3, 6, false, ASL(ab, read8, write8) }
		[0x0f]: { 3, 6,  true, SLO(ab, read8, write8) }
		[0x10]: { 2, 2, false, BRANCH(0x80, false) } -- BPL
		[0x11]: { 2, 5, false, ORA(indyp) }
		[0x12]: { 1, 2,  true, JAM }
		[0x13]: { 2, 8,  true, SLO(indy, read8, write8) }
		[0x14]: { 2, 4,  true, NOP(zpx) }
		[0x15]: { 2, 4, false, ORA(zpx) }
		[0x16]: { 2, 6, false, ASL(zpx, read8, write8) }
		[0x17]: { 2, 6,  true, SLO(zpx, read8, write8) }
		[0x18]: { 1, 2, false, CLC }
		[0x19]: { 3, 4, false, ORA(abyp) }
		[0x1a]: { 1, 2,  true, NOP(imp) }
		[0x1b]: { 3, 7,  true, SLO(aby, read8, write8) }
		[0x1c]: { 3, 4,  true, NOP(abxp) }
		[0x1d]: { 3, 4, false, ORA(abxp) }
		[0x1e]: { 3, 7, false, ASL(abx, read8, write8) }
		[0x1f]: { 3, 7,  true, SLO(abx, read8, write8) }
		[0x20]: { 3, 6, false, JSR	}
		[0x21]: { 2, 6, false, AND(indx) }
		[0x22]: { 1, 2,  true, JAM }
		[0x23]: { 2, 8,  true, RLA(indx, read8, write8) }
		[0x24]: { 2, 3, false, BIT(zp) }
		[0x25]: { 2, 3, false, AND(zp) }
		[0x26]: { 2, 5, false, ROL(zp, read8, write8) }
		[0x27]: { 2, 5,  true, RLA(zp, read8, write8) }
		[0x28]: { 1, 4, false, PLP }
		[0x29]: { 2, 2, false, AND(imm) }
		[0x2a]: { 1, 2, false, ROL(accum, accum, writea) }
		-- TODO: ANC imm
		[0x2c]: { 3, 4, false, BIT(ab) }
		[0x2d]: { 3, 4, false, AND(ab) }
		[0x2e]: { 3, 6, false, ROL(ab, read8, write8) }
		[0x2f]: { 3, 6,  true, RLA(ab, read8, write8) }
		[0x30]: { 2, 2, false, BRANCH(0x80, true) } -- BMI
		[0x31]: { 2, 5, false, AND(indyp) }
		[0x32]: { 1, 2,  true, JAM }
		[0x33]: { 2, 8,  true, RLA(indy, read8, write8) }
		[0x34]: { 2, 4,  true, NOP(zpx) }
		[0x35]: { 2, 4, false, AND(zpx) }
		[0x36]: { 2, 6, false, ROL(zpx, read8, write8) }
		[0x37]: { 2, 6,  true, RLA(zpx, read8, write8) }
		[0x38]: { 1, 2, false, SEC }
		[0x39]: { 3, 4, false, AND(abyp) }
		[0x3a]: { 1, 2,  true, NOP(imp) }
		[0x3b]: { 3, 7,  true, RLA(aby, read8, write8) }
		[0x3c]: { 3, 4,  true, NOP(abxp) }
		[0x3d]: { 3, 4, false, AND(abxp) }
		[0x3e]: { 3, 7, false, ROL(abx, read8, write8) }
		[0x3f]: { 3, 7,  true, RLA(abx, read8, write8) }
		[0x40]: { 1, 6, false, RTI }
		[0x41]: { 2, 6, false, EOR(indx) }
		[0x42]: { 1, 2,  true, JAM }
		[0x43]: { 2, 8,  true, SRE(indx, read8, write8) }
		[0x44]: { 2, 3,  true, NOP(zp) }
		[0x45]: { 2, 3, false, EOR(zp) }
		[0x46]: { 2, 5, false, LSR(zp, read8, write8) }
		[0x47]: { 2, 5,  true, SRE(zp, read8, write8) }
		[0x48]: { 1, 3, false, PHA }
		[0x49]: { 2, 2, false, EOR(imm) }
		[0x4a]: { 1, 2, false, LSR(accum, accum, writea) }
		-- TODO: ALR imm
		[0x4c]: { 3, 3, false, JMP(ab) }
		[0x4d]: { 3, 4, false, EOR(ab) }
		[0x4e]: { 3, 6, false, LSR(ab, read8, write8) }
		[0x4f]: { 3, 6,  true, SRE(ab, read8, write8) }
		[0x50]: { 2, 2, false, BRANCH(0x40, false) } -- BVC
		[0x51]: { 2, 5, false, EOR(indyp) }
		[0x52]: { 1, 2,  true, JAM }
		[0x53]: { 2, 8,  true, SRE(indy, read8, write8) }
		[0x54]: { 2, 4,  true, NOP(zpx) }
		[0x55]: { 2, 4, false, EOR(zpx) }
		[0x56]: { 2, 6, false, LSR(zpx, read8, write8) }
		[0x57]: { 2, 6,  true, SRE(zpx, read8, write8) }
		[0x58]: { 1, 2, false, CLI }
		[0x59]: { 3, 4, false, EOR(abyp) }
		[0x5a]: { 1, 2,  true, NOP(imp) }
		[0x5b]: { 3, 7,  true, SRE(aby, read8, write8) }
		[0x5c]: { 3, 4,  true, NOP(abxp) }
		[0x5d]: { 3, 4, false, EOR(abxp) }
		[0x5e]: { 3, 7, false, LSR(abx, read8, write8) }
		[0x5f]: { 3, 7,  true, SRE(abx, read8, write8) }
		[0x60]: { 1, 6, false, RTS }
		[0x61]: { 2, 6, false, ADC(indx) }
		[0x62]: { 1, 2,  true, JAM }
		[0x63]: { 2, 8,  true, RRA(indx) }
		[0x64]: { 2, 3,  true, NOP(zp) }
		[0x65]: { 2, 3, false, ADC(zp) }
		[0x66]: { 2, 5, false, ROR(zp, read8, write8) }
		[0x67]: { 2, 5,  true, RRA(zp) }
		[0x68]: { 1, 4, false, PLA }
		[0x69]: { 2, 2, false, ADC(imm) }
		[0x6a]: { 1, 2, false, ROR(accum, accum, writea) }
		-- TODO: ARR imm
		[0x6c]: { 3, 5, false, JMP(ind) }
		[0x6d]: { 3, 4, false, ADC(ab) }
		[0x6e]: { 3, 6, false, ROR(ab, read8, write8) }
		[0x6f]: { 3, 6,  true, RRA(ab) }
		[0x70]: { 2, 2, false, BRANCH(0x40, true) } -- BVS
		[0x71]: { 2, 5, false, ADC(indyp) }
		[0x72]: { 1, 2,  true, JAM }
		[0x73]: { 2, 8,  true, RRA(indy) }
		[0x74]: { 2, 4,  true, NOP(zpx) }
		[0x75]: { 2, 4, false, ADC(zpx) }
		[0x76]: { 2, 6, false, ROR(zpx, read8, write8) }
		[0x77]: { 2, 6,  true, RRA(zpx) }
		[0x78]: { 1, 2, false, SEI }
		[0x79]: { 3, 4, false, ADC(abyp) }
		[0x7a]: { 1, 2,  true, NOP(imp) }
		[0x7b]: { 3, 7,  true, RRA(aby) }
		[0x7c]: { 3, 4,  true, NOP(abxp) }
		[0x7d]: { 3, 4, false, ADC(abxp) }
		[0x7e]: { 3, 7, false, ROR(abx, read8, write8) }
		[0x7f]: { 3, 7,  true, RRA(abx) }
		[0x80]: { 2, 2,  true, NOP(imm) }
		[0x81]: { 2, 6, false, STA(indx) }
		[0x82]: { 2, 2,  true, NOP(imm) }
		[0x83]: { 2, 6,  true, SAX(indx) }
		[0x84]: { 2, 3, false, STY(zp) }
		[0x85]: { 2, 3, false, STA(zp) }
		[0x86]: { 2, 3, false, STX(zp) }
		[0x87]: { 2, 3,  true, SAX(zp) }
		[0x88]: { 1, 2, false, DEY}
		[0x89]: { 2, 2,  true, NOP(imm) }
		[0x8a]: { 1, 2, false, TXA }
		-- TODO: XAA imm
		[0x8c]: { 3, 4, false, STY(ab) }
		[0x8d]: { 3, 4, false, STA(ab) }
		[0x8e]: { 3, 4, false, STX(ab) }
		[0x8f]: { 3, 4,  true, SAX(ab) }
		[0x90]: { 2, 2, false, BRANCH(0x01, false) } -- BCC
		[0x91]: { 2, 6, false, STA(indy) }
		[0x92]: { 1, 2,  true, JAM }
		-- TODO: AHX indy
		[0x94]: { 2, 4, false, STY(zpx) }
		[0x95]: { 2, 4, false, STA(zpx) }
		[0x96]: { 2, 4, false, STX(zpy) }
		[0x97]: { 2, 4,  true, SAX(zpy) }
		[0x98]: { 1, 2, false, TYA }
		[0x99]: { 3, 5, false, STA(aby) }
		[0x9a]: { 1, 2, false, TXS }
		-- TODO: TAS aby
		-- TODO: SHY abx
		[0x9d]: { 3, 5, false, STA(abx) }
		-- TODO: SHX aby
		-- TODO: AHX aby
		[0xa0]: { 2, 2, false, LDY(imm) }
		[0xa1]: { 2, 6, false, LDA(indx) }
		[0xa2]: { 2, 2, false, LDX(imm) }
		[0xa3]: { 2, 6,  true, LAX(indx) }
		[0xa4]: { 2, 3, false, LDY(zp) }
		[0xa5]: { 2, 3, false, LDA(zp) }
		[0xa6]: { 2, 3, false, LDX(zp) }
		[0xa7]: { 2, 3,  true, LAX(zp) }
		[0xa8]: { 1, 2, false, TAY }
		[0xa9]: { 2, 2, false, LDA(imm) }
		[0xaa]: { 1, 2, false, TAX }
		[0xab]: { 2, 2,  true, LAX(imm) }
		[0xac]: { 3, 4, false, LDY(ab) }
		[0xad]: { 3, 4, false, LDA(ab) }
		[0xae]: { 3, 4, false, LDX(ab) }
		[0xaf]: { 3, 4,  true, LAX(ab) }
		[0xb0]: { 2, 2, false, BRANCH(0x01, true) } -- BCS
		[0xb1]: { 2, 5, false, LDA(indyp) }
		[0xb2]: { 1, 2,  true, JAM }
		[0xb3]: { 2, 5,  true, LAX(indyp) }
		[0xb4]: { 2, 4, false, LDY(zpx) }
		[0xb5]: { 2, 4, false, LDA(zpx) }
		[0xb6]: { 2, 4, false, LDX(zpy) }
		[0xb7]: { 2, 4,  true, LAX(zpy) }
		[0xb8]: { 1, 2, false, CLV }
		[0xb9]: { 3, 4, false, LDA(abyp) }
		[0xba]: { 1, 2, false, TSX }
		-- TODO: LAS aby
		[0xbc]: { 3, 4, false, LDY(abxp) }
		[0xbd]: { 3, 4, false, LDA(abxp) }
		[0xbe]: { 3, 4, false, LDX(abyp) }
		[0xbf]: { 3, 4,  true, LAX(abyp) }
		[0xc0]: { 2, 2, false, CPY(imm) }
		[0xc1]: { 2, 6, false, CMP(indx) }
		[0xc2]: { 2, 2,  true, NOP(imm) }
		[0xc3]: { 2, 8,  true, DCP(indx) }
		[0xc4]: { 2, 3, false, CPY(zp) }
		[0xc5]: { 2, 3, false, CMP(zp) }
		[0xc6]: { 2, 5, false, DEC(zp) }
		[0xc7]: { 2, 5,  true, DCP(zp) }
		[0xc8]: { 1, 2, false, INY }
		[0xc9]: { 2, 2, false, CMP(imm) }
		[0xca]: { 1, 2, false, DEX }
		-- TODO: AXS imm
		[0xcc]: { 3, 4, false, CPY(ab) }
		[0xcd]: { 3, 4, false, CMP(ab) }
		[0xce]: { 3, 6, false, DEC(ab) }
		[0xcf]: { 3, 6,  true, DCP(ab) }
		[0xd0]: { 2, 2, false, BRANCH(0x02, false) } -- BNE
		[0xd1]: { 2, 5, false, CMP(indyp) }
		[0xd2]: { 1, 2,  true, JAM }
		[0xd3]: { 2, 8,  true, DCP(indy) }
		[0xd4]: { 2, 4,  true, NOP(zpx) }
		[0xd5]: { 2, 4, false, CMP(zpx) }
		[0xd6]: { 2, 6, false, DEC(zpx) }
		[0xd7]: { 2, 6,  true, DCP(zpx) }
		[0xd8]: { 1, 2, false, CLD }
		[0xd9]: { 3, 4, false, CMP(abyp) }
		[0xda]: { 1, 2,  true, NOP(imp) }
		[0xdb]: { 3, 7,  true, DCP(aby) }
		[0xdc]: { 3, 4,  true, NOP(abxp) }
		[0xdd]: { 3, 4, false, CMP(abxp) }
		[0xde]: { 3, 7, false, DEC(abx) }
		[0xdf]: { 3, 7,  true, DCP(abx) }
		[0xe0]: { 2, 2, false, CPX(imm) }
		[0xe1]: { 2, 6, false, SBC(indx) }
		[0xe2]: { 2, 2,  true, NOP(imm) }
		[0xe3]: { 2, 8,  true, ISB(indx) }
		[0xe4]: { 2, 3, false, CPX(zp) }
		[0xe5]: { 2, 3, false, SBC(zp) }
		[0xe6]: { 2, 5, false, INC(zp) }
		[0xe7]: { 2, 5,  true, ISB(zp) }
		[0xe8]: { 1, 2, false, INX }
		[0xe9]: { 2, 2, false, SBC(imm) }
		[0xea]: { 1, 2, false, NOP(imp) }
		[0xeb]: { 2, 2,  true, SBC(imm) }
		[0xec]: { 3, 4, false, CPX(ab) }
		[0xed]: { 3, 4, false, SBC(ab) }
		[0xee]: { 3, 6, false, INC(ab) }
		[0xef]: { 3, 6,  true, ISB(ab) }
		[0xf0]: { 2, 2, false, BRANCH(0x02, true) } -- BEQ
		[0xf1]: { 2, 5, false, SBC(indyp) }
		[0xf2]: { 1, 2,  true, JAM }
		[0xf3]: { 2, 8,  true, ISB(indy) }
		[0xf4]: { 2, 4,  true, NOP(zpx) }
		[0xf5]: { 2, 4, false, SBC(zpx) }
		[0xf6]: { 2, 6, false, INC(zpx) }
		[0xf7]: { 2, 6,  true, ISB(zpx) }
		[0xf8]: { 1, 2, false, SED }
		[0xf9]: { 3, 4, false, SBC(abyp) }
		[0xfa]: { 1, 2,  true, NOP(imp) }
		[0xfb]: { 3, 7,  true, ISB(aby) }
		[0xfc]: { 3, 4,  true, NOP(abxp) }
		[0xfd]: { 3, 4, false, SBC(abxp) }
		[0xfe]: { 3, 7, false, INC(abx) }
		[0xff]: { 3, 7,  true, ISB(abx) }
	}

	miss = 0
	for i = 0, 0xff
		unless opcodes[i]
			--print("Missing opcode: %02x"\format(i))
			miss += 1
			opcodes[i] = opcodes[0x02]
	--print(miss, "opcodes missing")
	opcodes
