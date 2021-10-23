.PHONY: clean debug compile gnes

DEFAULT: gnes

clean:
	rm -rf build/*

compile: clean
	moonc -t build src
	mv build/src build/gnes
	cp -r assets build
	cp src/nativefs.lua build/gnes
	cp main.lua conf.lua build

debug: compile
	cp -r src/jit build/gnes

gnes: compile
	(cd build && zip -r9X gnes.love .)
