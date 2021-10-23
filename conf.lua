io.stdout:setvbuf('no')
print("LuaJIT", jit.version_num)

collectgarbage('setpause', 150) -- default 200
collectgarbage('setstepmul', 100) -- default 200

local JIT_MAGIC = 2 ^ 14
jit.opt.start(3,
	'-fuse', -- TODO: enabling this triggers a timing bug in PPU.instructions/vblank
	'maxtrace='   .. JIT_MAGIC,
	'maxrecord='  .. JIT_MAGIC,
	'maxirconst=' .. JIT_MAGIC,
	'maxside='    .. JIT_MAGIC,
	'maxsnap='    .. JIT_MAGIC,
	'maxmcode='   .. JIT_MAGIC * 8,
	'tryside='    .. 256 --JIT_MAGIC / 8
)

__MOONSCRIPT = not not love.filesystem.getInfo('MOONSCRIPT')

if __MOONSCRIPT then
	require('debugenv')
else
	package.path = package.path .. ';gnes/?.lua;gnes/?/init.lua'
	love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';gnes/?.lua;gnes/?/init.lua')
end

DEBUG = true
SCREEN_WIDTH = 256
SCREEN_HEIGHT = 240

function love.conf(t)
	t.version = '11.3'
	t.identity = "GrumpiNES"
	t.window.title = "GrumpiNES"
	t.window.width = SCREEN_WIDTH * 2
	t.window.height = SCREEN_HEIGHT * 2
	t.window.minwidth = SCREEN_WIDTH
	t.window.minheight = SCREEN_HEIGHT
	t.window.resizable = true
	t.window.vsync = __MOONSCRIPT and 0 or 1
	t.gammacorrect = false
end
