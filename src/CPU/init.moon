ffi = require('ffi')
import bor, band, bxor, bnot, lshift, rshift from require('bit')
import min, max from math

-- status flags (P)
-- 	C: 0x01 -- carry
-- 	Z: 0x02 -- zero
-- 	I: 0x04 -- interrupt disable
-- 	D: 0x08 -- bcd
-- 	B: 0x10 -- brk
-- 	X: 0x20 -- unused
-- 	V: 0x40 -- overflow
-- 	N: 0x80 -- negative

CPU_ct = ffi.typeof("
	struct {
		uint8_t A, X, Y, SP, P;
		uint16_t PC;

		uint8_t  _port[2]; // for 6510
		int _ir_requested;   // 0 or irq address vector
		int _ir_pending;   // 0 or irq address vector

		int _irq_line;
		int _nmi_line;

		int16_t _cycles;
		int8_t _delay_irq;
		uint8_t _instruction; // next instruction
		double _instCounter;
		double _cycleCounter;
	}
")

STACK = 0x100
NMI   = 0xfffa
RESET = 0xfffc
IRQ   = 0xfffe

(mem, BCD = true) ->
	state = CPU_ct!
	OPCODES, INSTRUCTIONS, TIMING = nil, nil, nil

	cpu = {
		:state

		step: =>
			@_step!
			state._cycleCounter += 1

		readPort: (addr) => state._port[addr]
		writePort: (addr, val) =>
			state._port[addr] = val
			val

		push8: (val) =>
			mem\write8(STACK + state.SP, val)
			state.SP -= 1

		pop8: =>
			state.SP += 1
			mem\read8(STACK + state.SP)

		push16: (val) =>
			@push8(band(rshift(val, 8), 0xff))
			@push8(band(val, 0xff))

		pop16: (val) => @pop8! + @pop8! * 0x100

		setC: (val) => state.P = band(bor(state.P, val), 0xfe + val)
		setZ: (val) => state.P = band(bor(state.P, val), 0xfd + val)
		setI: (val) => state.P = band(bor(state.P, val), 0xfb + val)
		setD: (val) => state.P = band(bor(state.P, val), 0xf7 + val)
		setV: (val) => state.P = band(bor(state.P, val), 0xbf + val)
		setN: (val) => state.P = band(bor(state.P, val), 0x7f + val)

		updateV: (op, p, m) =>
			@setV(band(bxor(op, p), band(bxor(op, m), 0x80)) / 2)
			op
		updateZ: (op) => @setZ(2 - min(op, 1) * 2)
		updateN: (op) => @setN(band(op, 0x80))
		updateZN: (op) =>
			p = state.P
			if op == 0
				p = band(bor(p, 0x02), 0x7f)
			else
				b = band(op, 0x80)
				p = band(bor(band(p, 0xfd), b), 0x7f + b)
			state.P = p
			op

		testStatus: (flag) => band(state.P, flag) > 0

		reset: (addr, status = 0x20) =>
			with state
				.A, .X, .Y, .SP, .P = 0, 0, 0, 0xfd, status
				.PC = addr or mem\read16(RESET)
				._port[0], ._port[1] = 0x2f, 0x37
				._ir_pending, ._ir_requested = 0, 0
				._cycles, ._instCounter = 0, 0
				._cycleCounter = 7
				@_step = @_fetch_cycle

		irq_low: =>
			state._irq_line = 1

		irq_high: =>
			state._irq_line = 0

		nmi: => state._ir_requested = NMI

		wait: (cycles) => state._cycles += cycles

		_pollInterrupts: =>
			with state
				._ir_pending = 0
				if ._irq_line > 0 and not @testStatus(0x04) and ._ir_requested == 0
					._ir_requested = IRQ

				if ._ir_requested > 0
					._ir_pending = ._ir_requested
					._ir_requested = 0
					return ._instruction == 0 -- BRK
			false

		_fetch_cycle: =>
			with state
				if ._cycles > 0
					._cycles -= 1
					return
				if ._delay_irq > 0
					._delay_irq -= 1
				elseif ._ir_pending > 0
					@_interrupt!
					._ir_pending = 0
			@_fetch!
			@_step = @_exec_cycle

		_exec_cycle: =>
			with state
				if ._cycles > 2
					._cycles -= 1
					return

				._cycles = 0
				if @_pollInterrupts!
					 -- NMI/IRQ interrupted BRK
					 -- TODO: check at which cycle the interrupt was requested and fix timing
					._instruction = mem\read8(mem\read16(._ir_pending))

				INSTRUCTIONS[._instruction](state)
				._instCounter += 1
				@_step = @_fetch_cycle

		_fetch: =>
			with state
				b = mem\read8(.PC)
				--FETCHHOOK(state, b, mem, OPCODES) if FETCHHOOK
				._instruction = b
				._cycles += TIMING[b]
				.PC += 1

		_interrupt: =>
			with state
				addr, ._ir_pending = ._ir_pending, 0
				._cycles += 7
				@push16(.PC)
				@push8(band(.P, 0xef))
				@setI(0x04)
				.PC = mem\read16(addr)
	}

	INSTRUCTIONS, TIMING = do
		OPCODES = require('CPU.opcodes')(cpu, state, mem, BCD)
		inst = { i, OPCODES[i][4] for i = 0, 255 }
		timing = ffi.new('int8_t[255]')
		timing[i] = OPCODES[i][2] for i = 0, 255
		inst, timing

	cpu

