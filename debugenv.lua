package.path = package.path .. ';src/?.lua;src/?/init.lua'

--require('jit.dump').on('t', '/tmp/nes_jit.log')

local moonscript = require('moonscript')
require('Logfile')
local debug_traceback = debug.traceback
debug.traceback = function(threadOrMsg, msgOrLevel, level)
	local util = require('moonscript.util')
	local errors = require('moonscript.errors')
	if type(threadOrMsg) == 'thread' then
		local thread, msg, level = threadOrMsg, msgOrLevel or '', level
		return errors.rewrite_traceback(util.trim(debug_traceback(thread, '', level)), msg)
	end

	local msg, level = threadOrMsg or '', msgOrLevel or 2
	return errors.rewrite_traceback(util.trim(debug_traceback('', level)), msg)
end
