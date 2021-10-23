ffi = require('ffi')
import band, bor, bxor, rshift, lshift from require('bit')
import min, max from math

ifRendering = (fn) ->
	(mem) =>
		return unless @renderingOn > 0
		fn(@, mem)

incH = do
	LUT = ffi.new('int16_t[4]', 0x0000, 0x0001, 0x041f, 0x0000)
	ifRendering(=>
		@bgPat[0], @bgPat[1] = @bgPat[1], @bgPat[2]
		@bgAttr[0], @bgAttr[1] = @bgAttr[1], @bgAttr[2]

		v = @vramAddr
		wrap = lshift(rshift(band(v, 0x1f) + 1, 5), 1)
		@vramAddr = bxor(v, LUT[wrap]) + LUT[wrap + 1]
	)

incV = ifRendering(=>
	@bgPat[0], @bgPat[1] = @bgPat[1], @bgPat[2]
	@bgAttr[0], @bgAttr[1] = @bgAttr[1], @bgAttr[2]

	v = @vramAddr
	if band(v, 0x7000) ~= 0x7000
		@vramAddr = v + 0x1000
	else
		v = band(v, 0x0fff)
		y = rshift(band(v, 0x03e0), 5) + 1
		if y == 30
			y, v = 0, bxor(v, 0x0800)
		else
			y = lshift(band(y, 0x1f), 5)
		@vramAddr = bor(band(v, 0x7c1f), y)
)

syncH = ifRendering(=>
	@vramAddr = bor(band(@vramAddr, 0x7be0), band(@tempAddr, 0x041f))
)

syncV = ifRendering(=>
	@vramAddr = bor(band(@vramAddr, 0x041f), band(@tempAddr, 0x7be0))
	--@_updateA12(@vramAddr)
)

_fetchNT = (mem) => mem.readVRAM(0x2000 + band(@vramAddr, 0xfff))

fetchNT = ifRendering((mem) =>
	@bgTile = _fetchNT(@, mem)
)

fetchDummyNT = ifRendering((mem) =>
	_fetchNT(@, mem)
	nil
)

fetchAT = ifRendering((mem) =>
	v = @vramAddr
	at = do
		addr = bor(0x3c0, band(v, 0x0c00), band(rshift(v, 4), 0x38), band(rshift(v, 2), 0x07))
		mem.readVRAM(0x2000 + addr)

	shift = bor(band(rshift(v, 4), 0x04), band(v, 0x02))
	at = band(rshift(at, shift), 0x03)
	@bgAttr[2] = at
)

fetchDummyAT = ifRendering((mem) =>
	v = @vramAddr
	addr = bor(0x3c0, band(v, 0x0c00), band(rshift(v, 4), 0x38), band(rshift(v, 2), 0x07))
	mem.readVRAM(0x2000 + addr)
	nil
)

_fetchLoBG = (mem) =>
	addr = @bgTile * 16 + band(rshift(@vramAddr, 12), 0x07)
	mem.readCHR(@bgTable + addr)

fetchLoBG = ifRendering((mem) =>
	@bgPatLo = _fetchLoBG(@, mem)
)

fetchDummyLoBG = ifRendering((mem) =>
	_fetchLoBG(@, mem)
	nil
)

_fetchHiBG = (mem) =>
	addr = @bgTile * 16 + band(rshift(@vramAddr, 12), 0x07) + 8
	mem.readCHR(@bgTable + addr)

fetchHiBG = ifRendering((mem) =>
	@bgPat[2] = @bgPatLo * 0x100 + _fetchHiBG(@, mem)
)

fetchDummyHiBG = ifRendering((mem) =>
	_fetchHiBG(@, mem)
	nil
)

clearOAM = ifRendering(=>
	@oam2[@OAM2addr] = 0xff
	@OAM2addr = band(@OAM2addr + 1, 0x1f)
)

resetOAMAddr = ifRendering(=>
	@OAMaddr = 0
)

readOAM = ifRendering(=>
	return unless @OAM2addr < 32
	@oam2[@OAM2addr] = @oam[@OAMaddr]
)

writeOAM0 = ifRendering(=>
	return unless @OAMaddr < 255
	do
		d = @y - @oam2[0]
		if d < 0 or d >= @sprSize
			@spr0Active[1] = 0
			return

	@spr0Active[1] = 1
	@oam2[1] = @oam[@OAMaddr + 1] -- tile
	@oam2[2] = @oam[@OAMaddr + 2] -- attributes
	@oam2[3] = @oam[@OAMaddr + 3] -- x
	@OAMaddr = min(255, @OAMaddr + 4)
	@OAM2addr += 4
	@numNextSprites = 1
)

writeOAM = ifRendering(=>
	return unless @OAMaddr < 255

	addr = @OAM2addr
	d = @y - @oam2[addr]
	if d >= 0 and d < @sprSize
		if @numNextSprites > 7  -- sprite overflow
			@status = bor(@status, 0x20)
		else
			inaddr = @OAMaddr
			@oam2[addr + 1] = @oam[inaddr + 1] -- tile
			@oam2[addr + 2] = @oam[inaddr + 2] -- attributes
			@oam2[addr + 3] = @oam[inaddr + 3] -- x
			@numNextSprites += 1
			@OAM2addr += 4
	@OAMaddr = min(255, @OAMaddr + 4)
)

fetchSPRAT = ifRendering((mem) =>
	r = rshift(@x - 259, 1)
	w = lshift(r, 1)
	spr, oam = @sprites, @oam2
	spr[w + 3] = oam[r + 3] -- x
	spr[w + 0] = oam[r + 0] -- y
	spr[w + 1] = oam[r + 1] -- tile
	attr = oam[r + 2]
	spr[w + 2] = attr
	@sprFlipH = rshift(band(attr, 0x40), 6)
	@sprFlipV = rshift(band(attr, 0x80), 7)
)

reverse = (b) ->
	r = bor(rshift(band(b, 0xf0), 4), lshift(band(b, 0x0f), 4))
	r = bor(rshift(band(r, 0xcc), 2), lshift(band(r, 0x33), 2))
	bor(rshift(band(r, 0xaa), 1), lshift(band(r, 0x55), 1))

fetchLoSPR = ifRendering((mem) =>
	spr = @sprites
	index = @x - 262

	addr = do
		tile = spr[index + 1]
		height = @sprSize
		offs = do
			offs = bxor(max(0, @y - spr[index]), @sprFlipV * (height - 1))
			bor(band(offs, 7), lshift(band(offs, 8), 1))
		long = rshift(height, 4)
		offs += lshift(@sprTable + band(tile, long), 12)
		offs + rshift(tile, long) * lshift(height, 1)

	@sprAddr = addr
	chr = mem.readCHR(addr)
	spr[index + 4] = @sprFlipH > 0 and reverse(chr) or chr
)

fetchHiSPR = ifRendering((mem) =>
	chr = mem.readCHR(@sprAddr + 8)
	@sprites[@x - 264 + 5] = @sprFlipH > 0 and reverse(chr) or chr
)

_renderSprite0 = (x, y, bgColor, hitBG, mem) => -- sprite #0 in oam2
	d = 7 - (x - @sprites[3])
	return bgColor if d < 0 or d > 7

	p = band(rshift(@sprites[4], d), 0x01) + band(rshift(@sprites[5], d), 0x01) * 2
	return bgColor if p == 0

	do
		under255 = (1 - max(0, min(1, x - 254)))
		hit = hitBG * under255 * @spr0Active[0] -- TODO: band(hitBG, under255, @sprActive[0])
		@zeroHit = bor(@zeroHit, lshift(hit, 8))
	at = @sprites[2]
	pri = band(rshift(at, 5), 0x01) * hitBG
	col = lshift(band(at, 0x03), 2)
	bgColor * pri + mem.readPAL(0x3f10 + col + p) * (1 - pri), true

_renderSprite = (n, x, y, bgColor, hitBG, mem) => -- sprites > #0 in oam2
	d = 7 - (x - @sprites[n + 3])
	return bgColor if d < 0 or d > 7

	p = band(rshift(@sprites[n + 4], d), 0x01) + band(rshift(@sprites[n + 5], d), 0x01) * 2
	return bgColor if p == 0

	at = @sprites[n + 2]
	pri = band(rshift(at, 5), 0x01) * hitBG
	col = lshift(band(at, 0x03), 2)
	bgColor * pri + mem.readPAL(0x3f10 + col + p) * (1 - pri), true

bgRenderer = (x, y, mem) =>
	return mem.readPAL(0x3f00), 0 if x < @clipBG

	pix = band(x, 7)
	chrLo, chrHi = do
		fx = 7 - @fineX
		c1, c2 = @bgPat[0], @bgPat[1]
		lo = bor(lshift(rshift(c1, 8), pix), rshift(rshift(c2, 8), 8 - pix))
		hi = bor(lshift(band(c1, 0xff), pix), rshift(band(c2, 0xff), 8 - pix))
		m = lshift(1, fx)
		rshift(band(lo, m), fx), rshift(band(hi, m), fx)

	hitBG = bor(chrLo, chrHi)
	palLo = chrHi * 2 + chrLo
	palHi = hitBG * 4 * @bgAttr[band(rshift(@fineX + pix, 3), 0x01)]
	mem.readPAL(0x3f00 + palHi + palLo), hitBG

render = (mem) =>
	x, y = @x, @y
	res, hitBG = bgRenderer(@, x, y, mem)

	if @numSprites > 0 and x >= @clipSpr
		res, done = _renderSprite0(@, x, y, res, hitBG, mem)
		--done or= @numSprites == 1
		i = 1
		while not done and i < @numSprites
			res, done = _renderSprite(@, i * 8, x, y, res, hitBG, mem)
			i += 1
			--done or= i == @numSprites

	@frameBuffer[x + y * SCREEN_WIDTH] = res
	@zeroHit = rshift(@zeroHit, 1)
	@status = bor(@status, band(@zeroHit, 0x40))

renderBG = (mem) =>
	x, y = @x, @y
	@frameBuffer[x + y * SCREEN_WIDTH] = bgRenderer(@, x, y, mem)

scanlineStart = =>
	@numSprites, @numNextSprites = @numNextSprites, 0
	@OAM2addr = 0
	@spr0Active[0], @spr0Active[1] = @spr0Active[1], 0

idle = =>

skipOnOdd = =>
	@x += min(1, @oddFrame * @renderingOn)

frameStart = (mem) =>
	@lastStatusRead = 0

enterVBL = => -- 82182
	return @present! if band(@status, 0x80) == 0

	if @cycleCount - @lastStatusRead < 2
		@status = bor(@status, 0x80)
		return @present!

	@status, @nmiFired = bor(@status, 0x80), 1
	@nmi!
	@present!

setVBL = => -- 82180
	-- https://wiki.nesdev.com/w/index.php/PPU_frame_timing#VBL_Flag_Timing
	@status = bor(@status, 0x80) if @lastStatusRead < @cycleCount

clearVBL = => -- 89000
	@status = band(@status, 0x7f)

clearSPRFlags = => -- 89001
	@status = band(@status, 0x9f)

vblank = =>
	-- BUG: LuaJIT optimization option 'fuse' must stay disabled or this fails when jit is enabled.
	-- Reproducible with tests/ppu_vbl_nmi/rom_singles/04-nmi_control.nes
	-- Correct result only with jit.off() or option '-fuse'
	-- TODO: isolate cause of bug
	return unless @nmiFired == 0 and band(@status, 0x80) + band(@ctrl, 0x80) == 0x100
	@nmiFired = 1
	@nmi!

leaveVBL = =>
	@status = band(@status, 0x1f)
	@nmiFired = 0

{
	:idle
	:incH
	:incV
	:syncH
	:syncV
	:fetchNT
	:fetchDummyNT
	:fetchAT
	:fetchDummyAT
	:fetchLoBG
	:fetchDummyLoBG
	:fetchHiBG
	:fetchDummyHiBG
	:render
	:renderBG
	:fetchLoSPR
	:fetchHiSPR
	:fetchSPRAT
	:clearOAM
	:resetOAMAddr
	:readOAM
	:writeOAM
	:writeOAM0
	:enterVBL
	:leaveVBL
	:setVBL
	:clearVBL
	:clearSPRFlags
	:vblank
	:frameStart
	:scanlineStart
	:skipOnOdd
}
