(nes) ->
	import graphics from love

	screenImg = graphics.newImage(nes\getScreen!)
	screenImg\setFilter('nearest')
	screenCanvas = graphics.newCanvas(SCREEN_WIDTH, SCREEN_HEIGHT)

	paletteImg, palette = require('PPU.Palette')(nes)

	palShader = graphics.newShader([[
		uniform Image pal;
		uniform vec3 emphasis;
		const float offset = 1.0 / 128.0;

		vec4 effect(vec4 col, Image tex, vec2 uv, vec2 fc) {
			float t = Texel(tex, uv).r * 4.0;
			vec4 c = Texel(pal, vec2(t + offset, .5));
			return vec4(col.rgb * emphasis * c.rgb, 1.0);
		}
	]])
	palShader\send('pal', paletteImg)
	palShader\send('emphasis', { 1.0, 1.0, 1.0 })

	outputShader = graphics.newShader([[
		uniform vec2 pixelSize;
		uniform vec2 aberration;

		const vec3 dark = vec3(.75, .75, .75);
		const vec3 bright = vec3(1.5, 1.5, 1.5);
		const vec3 RGB[3] = vec3[3](
			vec3(1.2, .9, .9),
			vec3(.9, 1.2, .9),
			vec3(.9, .9, 1.2)
		);

		vec4 effect(vec4 col, Image tex, vec2 uv, vec2 fc) {
			float oddline = mod(fc.y + .5, 2.0);
			vec3 modifier = RGB[int(mod(fc.x + fc.y, 3.0))];
			vec3 above = Texel(tex, vec2(uv.x, uv.y - pixelSize.y * .5)).rgb;
			vec3 c = modifier * vec3(
				Texel(tex, uv - pixelSize * oddline * aberration).r,
				Texel(tex, uv).g,
				Texel(tex, uv + pixelSize * oddline * aberration).b
			);

			return vec4(mix(c * dark, (c + above * .5), (1.0 - oddline)), 1.0);
		}
	]])

	useShader = true
	useFilter = true
	hideOverscan = true

	with outputShader
		\send('pixelSize', { 1 / screenCanvas\getWidth!, 1 / screenCanvas\getHeight! })
		\send('aberration', { .5, .5 })

	{
		getDimensions: => screenCanvas\getDimensions!

		capture: =>
			pixels = {}
			nes\getScreen!\mapPixel((x, y, r) ->
				pixels[y * 341 + x] = math.floor(r * 255 + .5)
				r, r, r, r
			)

			t = love.image.newImageData(screenImg\getDimensions!)
			t\mapPixel((x, y) ->
				c = pixels[y * 341 + x]
				r = palette[c * 3 + 1] / 255
				g = palette[c * 3 + 2] / 255
				b = palette[c * 3 + 3] / 255
				r, g, b, 1
			)
			t

		toggleShader: => useShader = not useShader

		toggleFilter: =>
			useFilter = not useFilter
			screenCanvas\setFilter(useFilter and 'linear' or 'nearest')

		toggleOverscan: => hideOverscan = not hideOverscan

		render: (newScreenPixels) =>
			screenImg\replacePixels(newScreenPixels) if newScreenPixels
			with graphics
				.push('all')
				.reset!
				@_drawGame!
				x, y, scale = do
					sx, sy = .getDimensions!
					scale = math.min(sx / SCREEN_WIDTH, sy / SCREEN_HEIGHT)
					x, y = math.floor((sx - SCREEN_WIDTH * scale) * .5), math.floor((sy - SCREEN_HEIGHT * scale) * .5)
					x, y, scale

				.setBlendMode('none')
				.setShader(outputShader) if useShader
				.translate(x, y)
				.scale(scale)

				.draw(screenCanvas)

				.setShader!
				@_drawOverscan! if hideOverscan
				.pop!
				return x, y, scale

		_drawGame: =>
			with graphics
				.setCanvas(screenCanvas)
				.setShader(palShader)
				.draw(screenImg)
				.setShader!
				.setCanvas!

		_drawOverscan: =>
			with graphics
				.setColor(.2, .2, .2)
				.rectangle('fill', 0, 0, SCREEN_WIDTH, 8) -- top
				.rectangle('fill', 0, SCREEN_HEIGHT - 8, SCREEN_WIDTH, 8) -- bottom
				.rectangle('fill', 0, 8, 8, SCREEN_HEIGHT - 16) -- left
				.rectangle('fill', SCREEN_WIDTH - 8, 8, 8, SCREEN_HEIGHT - 16) -- right
	}
