import thread from love

threadFn = (...) ->
	require('love.audio')
	require('love.sound')
	require('love.timer')

	input, output = ...


thread.newThread(string.dump(threadFn))
