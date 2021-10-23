INST = require('PPU.instructions')

import idle, vblank, enterVBL, clearSPRFlags, leaveVBL, frameStart, scanlineStart from INST
import skipOnOdd, setVBL, clearVBL from INST
import fetchNT, fetchDummyNT, fetchAT, fetchDummyAT from INST
import fetchLoBG, fetchDummyLoBG, fetchHiBG, fetchDummyHiBG from INST
import render, renderBG, incH, incV, syncH, syncV from INST
import fetchLoSPR, fetchHiSPR, fetchSPRAT from INST
import evalSPR, clearOAM, resetOAMAddr, readOAM, writeOAM0, writeOAM from INST

dup = (first, last, frm, to) =>
	range = (last - first) + 1
	@[i] = @[first + (i - frm) % range] for i = frm, to

STATE_VIS0 = do -- scanline 0
	oamr_render = (mem) =>
		readOAM(@, mem)
		renderBG(@, mem)

	ops = { i, idle for i = 0, 340 }
	ops[  0] = (mem) =>
		frameStart(@, mem)
		scanlineStart(@, mem)
		renderBG(@, mem)
	ops[  1] = renderBG
	ops[  2] = (mem) =>
		clearOAM(@, mem)
		fetchNT(@, mem)
		renderBG(@, mem)
	ops[  3] = renderBG
	ops[  4] = (mem) =>
		clearOAM(@, mem)
		fetchAT(@, mem)
		renderBG(@, mem)
	ops[  5] = renderBG
	ops[  6] = (mem) =>
		clearOAM(@, mem)
		fetchLoBG(@, mem)
		renderBG(@, mem)
	ops[  7] = renderBG
	ops[  8] = (mem) =>
		clearOAM(@, mem)
		fetchHiBG(@, mem)
		incH(@, mem)
		renderBG(@, mem)
	dup(ops, 1, 8, 9, 64)

	ops[ 65] = oamr_render
	ops[ 66] = (mem) =>
		writeOAM0(@, mem)
		fetchNT(@, mem)
		renderBG(@, mem)
	ops[ 67] = oamr_render
	ops[ 68] = (mem) =>
		writeOAM(@, mem)
		fetchAT(@, mem)
		renderBG(@, mem)
	ops[ 69] = oamr_render
	ops[ 70] = (mem) =>
		writeOAM(@, mem)
		fetchLoBG(@, mem)
		renderBG(@, mem)
	ops[ 71] = oamr_render
	ops[ 72] = (mem) =>
		writeOAM(@, mem)
		fetchHiBG(@, mem)
		incH(@, mem)
		renderBG(@, mem)

	ops[ 73] = oamr_render
	ops[ 74] = (mem) =>
		writeOAM(@, mem)
		fetchNT(@, mem)
		renderBG(@, mem)
	ops[ 75] = oamr_render
	ops[ 76] = (mem) =>
		writeOAM(@, mem)
		fetchAT(@, mem)
		renderBG(@, mem)
	ops[ 77] = oamr_render
	ops[ 78] = (mem) =>
		writeOAM(@, mem)
		fetchLoBG(@, mem)
		renderBG(@, mem)
	ops[ 79] = oamr_render
	ops[ 80] = (mem) =>
		writeOAM(@, mem)
		fetchHiBG(@, mem)
		incH(@, mem)
		renderBG(@, mem)

	dup(ops, 73, 80, 81, 248)

	ops[249] = oamr_render
	ops[250] = (mem) =>
		writeOAM(@, mem)
		fetchDummyNT(@, mem)
		renderBG(@, mem)
	ops[251] = oamr_render
	ops[252] = (mem) =>
		writeOAM(@, mem)
		fetchDummyAT(@, mem)
		renderBG(@, mem)
	ops[253] = oamr_render
	ops[254] = (mem) =>
		writeOAM(@, mem)
		fetchDummyLoBG(@, mem)
		renderBG(@, mem)
	ops[255] = oamr_render
	ops[256] = (mem) =>
		writeOAM(@, mem)
		fetchDummyHiBG(@, mem)
		incV(@, mem)

	ops[257] = (mem) =>
		resetOAMAddr(@, mem)
		syncH(@, mem)
	ops[258] = fetchDummyNT
	ops[259] = idle
	ops[260] = (mem) =>
		fetchSPRAT(@, mem)
		fetchDummyAT(@, mem)
	ops[261] = idle
	ops[262] = fetchLoSPR
	ops[263] = idle
	ops[264] = fetchHiSPR

	ops[265] = idle
	ops[266] = fetchDummyNT
	ops[267] = fetchSPRAT
	ops[268] = fetchDummyAT
	ops[269] = idle
	ops[270] = fetchLoSPR
	ops[271] = idle
	ops[272] = fetchHiSPR
	dup(ops, 265, 272, 273, 320)

	ops[321] = idle
	ops[322] = fetchNT
	ops[323] = idle
	ops[324] = fetchAT
	ops[325] = idle
	ops[326] = fetchLoBG
	ops[327] = idle
	ops[328] = (mem) =>
		fetchHiBG(@, mem)
		incH(@, mem)
	dup(ops, 321, 328, 329, 336)

	ops[337] = idle
	ops[338] = fetchDummyNT
	ops[339] = idle
	ops[340] = fetchDummyNT

	ops

STATE_VIS1 = do -- scanlines 1 .. 239
	oamr_render = (mem) =>
		readOAM(@, mem)
		render(@, mem)

	ops = { i, idle for i = 0, 340 }

	ops[  0] = (mem) =>
		scanlineStart(@, mem)
		render(@, mem)
	ops[  1] = render
	ops[  2] = (mem) =>
		clearOAM(@, mem)
		fetchNT(@, mem)
		render(@, mem)
	ops[  3] = render
	ops[  4] = (mem) =>
		clearOAM(@, mem)
		fetchAT(@, mem)
		render(@, mem)
	ops[  5] = render
	ops[  6] = (mem) =>
		clearOAM(@, mem)
		fetchLoBG(@, mem)
		render(@, mem)
	ops[  7] = render
	ops[  8] = (mem) =>
		clearOAM(@, mem)
		fetchHiBG(@, mem)
		incH(@, mem)
		render(@, mem)
	dup(ops, 1, 8, 9, 64)

	ops[ 65] = oamr_render
	ops[ 66] = (mem) =>
		writeOAM(@, mem)
		fetchNT(@, mem)
		render(@, mem)
	ops[ 67] = oamr_render
	ops[ 68] = (mem) =>
		writeOAM(@, mem)
		fetchAT(@, mem)
		render(@, mem)
	ops[ 69] = oamr_render
	ops[ 70] = (mem) =>
		writeOAM(@, mem)
		fetchLoBG(@, mem)
		render(@, mem)
	ops[ 71] = oamr_render
	ops[ 72] = (mem) =>
		writeOAM(@, mem)
		fetchHiBG(@, mem)
		incH(@, mem)
		render(@, mem)

	dup(ops, 65, 72, 73, 248)
	ops[ 66] = (mem) =>
		writeOAM0(@, mem)
		fetchNT(@, mem)
		render(@, mem)

	ops[249] = oamr_render
	ops[250] = (mem) =>
		writeOAM(@, mem)
		fetchDummyNT(@, mem)
		render(@, mem)
	ops[251] = oamr_render
	ops[252] = (mem) =>
		writeOAM(@, mem)
		fetchDummyAT(@, mem)
		render(@, mem)
	ops[253] = oamr_render
	ops[254] = (mem) =>
		writeOAM(@, mem)
		fetchDummyLoBG(@, mem)
		render(@, mem)
	ops[255] = oamr_render
	ops[256] = (mem) =>
		writeOAM(@, mem)
		fetchDummyHiBG(@, mem)
		incV(@, mem)

	ops[257] = (mem) =>
		resetOAMAddr(@, mem)
		syncH(@, mem)
	ops[258] = fetchDummyNT
	ops[259] = idle
	ops[260] = (mem) =>
		fetchSPRAT(@, mem)
		fetchDummyAT(@, mem)
	ops[261] = idle
	ops[262] = fetchLoSPR
	ops[263] = idle
	ops[264] = fetchHiSPR

	ops[265] = idle
	ops[266] = fetchDummyNT
	ops[267] = fetchSPRAT
	ops[268] = fetchDummyAT
	ops[269] = idle
	ops[270] = fetchLoSPR
	ops[271] = idle
	ops[272] = fetchHiSPR
	dup(ops, 265, 272, 273, 320)

	ops[321] = idle
	ops[322] = fetchNT
	ops[323] = idle
	ops[324] = fetchAT
	ops[325] = idle
	ops[326] = fetchLoBG
	ops[327] = idle
	ops[328] = (mem) =>
		fetchHiBG(@, mem)
		incH(@, mem)
	dup(ops, 321, 328, 329, 336)

	ops[337] = idle
	ops[338] = fetchDummyNT
	ops[339] = idle
	ops[340] = fetchDummyNT

	ops

STATE_POST = do -- scanline 240
	ops = { i, idle for i = 0, 340 }
	ops[340] = setVBL
	ops

STATE_VBL0 = do -- scanline 241
	ops = { i, vblank for i = 0, 340 }
	ops[0] = idle
	ops[1] = enterVBL
	ops

STATE_VBL1 = do -- scanlines 242 .. 260
	ops = { i, vblank for i = 0, 340 }
	ops

STATE_VBL2 = do
	ops = { i, vblank for i = 0, 340 }
	ops[340] = (mem) =>
		--vblank(@, mem)
		clearVBL(@, mem)
	ops

STATE_PRE = do  -- scanline 261
	ops = { i, idle for i = 0, 340 }
	ops[  0] = (mem) =>
		scanlineStart(@, mem)
		clearSPRFlags(@, mem)
	ops[  1] = idle -- replaced with leaveVBL below
	ops[  2] = fetchNT
	ops[  3] = idle
	ops[  4] = fetchAT
	ops[  5] = idle
	ops[  6] = fetchLoBG
	ops[  7] = idle
	ops[  8] = (mem) =>
		fetchHiBG(@, mem)
		incH(@, mem)
	dup(ops, 1, 8, 9, 248)

	ops[249] = idle
	ops[250] = fetchDummyNT
	ops[251] = idle
	ops[252] = fetchDummyAT
	ops[253] = idle
	ops[254] = fetchDummyLoBG
	ops[255] = idle
	ops[256] = (mem) =>
		fetchDummyHiBG(@, mem)
		incV(@, mem)

	ops[257] = (mem) =>
		resetOAMAddr(@, mem)
		syncH(@, mem)
	ops[258] = fetchDummyNT
	ops[259] = fetchSPRAT
	ops[260] = fetchDummyAT
	ops[261] = idle
	ops[262] = fetchLoSPR
	ops[263] = idle
	ops[264] = fetchHiSPR

	ops[265] = idle
	dup(ops, 258, 264, 266, 272)
	dup(ops, 265, 271, 273, 279)
	ops[280] = (mem) =>
		fetchHiSPR(@, mem)
		syncV(@, mem)
	ops[281] = syncV
	ops[282] = (mem) =>
		syncV(@, mem)
		fetchDummyNT(@, mem)
	ops[283] = (mem) =>
		syncV(@, mem)
		fetchSPRAT(@, mem)
	ops[284] = (mem) =>
		syncV(@, mem)
		fetchDummyAT(@, mem)
	ops[285] = syncV
	ops[286] = (mem) =>
		syncV(@, mem)
		fetchLoSPR(@, mem)
	ops[287] = syncV
	ops[288] = (mem) =>
		syncV(@, mem)
		fetchHiSPR(@, mem)
	dup(ops, 281, 288, 289, 304)
	dup(ops, 265, 272, 305, 320)

	dup(ops, 1, 8, 321, 336)

	ops[1] = leaveVBL

	ops[337] = idle
	ops[338] = (mem) =>
		skipOnOdd(@, mem)
		fetchDummyNT(@, mem)
	ops[339] = idle
	ops[340] = fetchDummyNT

	ops

STATES = {}

STATES[0] = STATE_VIS0
STATES[i] = STATE_VIS1 for i = 1, 239
STATES[240] = STATE_POST
STATES[241] = STATE_VBL0
STATES[i] = STATE_VBL1 for i = 242, 259
STATES[260] = STATE_VBL2
STATES[261] = STATE_PRE

STATES
