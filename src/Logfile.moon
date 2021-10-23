import filesystem from love
import band from require('bit')
MNEMONICS = require('CPU.mnemonics')
OPCODES = require('CPU.opcodes')

logfile = nil

export log = (fmt, ...) ->
	logfile or= filesystem.newFile('lnes.log', 'w')
	with logfile
		\write(fmt\format(...))
		\write('\n')

formatStatus = (s) ->
	"%s%s%s%s%s%s%s%s"\format(
		(band(s, 0x80) > 0 and 'N' or '.'),
		(band(s, 0x40) > 0 and 'V' or '.'),
		'-',
		(band(s, 0x10) > 0 and 'B' or '.'),
		(band(s, 0x08) > 0 and 'D' or '.'),
		(band(s, 0x04) > 0 and 'I' or '.'),
		(band(s, 0x02) > 0 and 'Z' or '.'),
		(band(s, 0x01) > 0 and 'C' or '.')
	)

formatInst = (mem, pc, size) ->
	ops = [ "%02X"\format(mem\read8(pc + i)) for i = 0, size ]
	table.concat(ops, ' ')

logLine = (state, op, size, mem, ppux, ppuy) ->
	with state
		inst = formatInst(mem, .PC, size)
		log("%04X  %-9s %-31s A:%02X X:%02X Y:%02X P:%02X SP:%02X PPU:%3d,%3d CYC:%-8d %s"\format(
			.PC, inst, MNEMONICS[op], .A, .X, .Y, .P, .SP, ppux, ppuy, tonumber(._cycleCounter), formatStatus(.P)
		))

export FETCHHOOK = (state, op, mem, opcodes) ->
	px, py = nes\getPPU!\getState!
	px -= 3
	if px < 0
		py -= 1
		px += 341
		if py < 0
			py = 261
	size = opcodes[op][1] - 1
	logLine(state, op, size, mem, px, py)

