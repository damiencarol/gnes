(nes) ->
	PAL = require("PPU.#{nes\getCart!\getSystem!}.palette")

	pal = love.image.newImageData(64, 1)
	pal\mapPixel((x) ->
		r, g, b = PAL[x * 3 + 1], PAL[x * 3 + 2], PAL[x * 3 + 3]
		r / 255, g / 255, b / 255, 1.0
	)

	palImg = love.graphics.newImage(pal)
	palImg\setFilter('nearest')
	palImg, PAL

