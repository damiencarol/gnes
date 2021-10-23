ffi = require('ffi')
import band, lshift, rshift from require('bit')

ffi.cdef([[
	typedef struct __attribute__((__packed__)) {
		uint8_t header[4]; // NES\x1a
		uint8_t prg_rom_size_lsb;
		uint8_t chr_rom_size_lsb;
		uint8_t flags6;
		uint8_t flags7;
		uint8_t mapper_msb;
		uint8_t rom_size_msb;
		uint8_t prg_ram_size;
		uint8_t chr_ram_size;
		uint8_t timing;
		uint8_t system_type;
		uint8_t misc_roms;
		uint8_t expansion;
	} NESHeader_ct;
]])

class Cart
	new: (rom) =>
		error("Invalid ROM file") unless rom\sub(1, 4) == 'NES\x1a'

		@_prgROM, @_prgRAM, @_chrROM = nil, nil, nil
		@_prgROMSize, @_prgRAMSize, @_chrROMSize, @_chrRAMSize = 0, 0, 0, 0
		@_mapperId = 0
		@_trainer = false
		@_system = 'NTSC'
		@_ntMirroring = 0
		@_loadROM(ffi.cast('char*', rom))

	getSystem: => @_system
	getPRGROM: => @_prgROM
	getPRGRAM: => @_prgRAM
	getCHRROM: => @_chrROM
	getCHRRAM: => @_chrRAM
	getPRGROMSize: => @_prgROMSize
	getPRGRAMSize: => @_prgRAMSize
	getCHRROMSize: => @_chrROMSize
	getCHRRAMSize: => @_chrRAMSize
	getNTMirroring: => @_ntMirroring
	getMapper: => @_mapperId

	_loadROM: (data) =>
		header = ffi.cast('NESHeader_ct*', data)
		version = rshift(band(header.flags7, 0x0c), 2)
		@_parsers[@_detectFormat(header, 0)](@, header)

		print("ROM version", version)
		print("Mapper", @_mapperId)
		print("System", @_system)
		print("PRG-ROM", @_prgROMSize)
		print("PRG-RAM", @_prgRAMSize)
		print("CHR-ROM", @_chrROMSize)
		print("CHR-RAM", @_chrRAMSize)
		print("Name table mirroring", @_ntMirroring)
		--print("Trainer", @_trainer)

		@_chrRAM = ffi.new('uint8_t[?]', @_chrRAMSize) if @_chrRAMSize > 0
		@_prgRAM = ffi.new('uint8_t[?]', @_prgRAMSize)
		@_loadData(data, 16 + (@_trainer and 0x200 or 0))

	_detectFormat: (header, size) =>
		with header
			ver = band(.flags7, 0x0c)
			switch ver
				when 0x08
					return 'ines2' -- TODO: improve check
				when 0x00
					if .timing + .system_type + .misc_roms + .expansion == 0
						return 'ines'
		'archaic'

	_loadData: (data, offs) =>
		if @_prgROMSize > 0
			@_prgROM = ffi.new('uint8_t[?]', @_prgROMSize)
			ffi.copy(@_prgROM, data + offs , @_prgROMSize)

		offs += @_prgROMSize
		if @_chrROMSize > 0
			@_chrROM = ffi.new('uint8_t[?]', @_chrROMSize)
			ffi.copy(@_chrROM, data + offs, @_chrROMSize)

	_parsers: {
		archaic: (header) =>
			print("WARNING: 'archaic' iNES format NYI. Using fallback")
			Cart._parsers.ines(header)

		ines: (header) =>
			with header
				@_prgROMSize = (.prg_rom_size_lsb + band(.rom_size_msb, 0x0f) * 0x100) * 16384
				@_chrROMSize = (.chr_rom_size_lsb + band(.rom_size_msb, 0xf0) / 0x10) * 8192
				@_prgRAMSize = .prg_ram_size > 0 and .prg_ram_size * 8192 or 8192
				@_chrRAMSize = @_chrROMSize == 0 and 8192 or 0
				@_mapperId = band(.flags6, 0xf0) / 0x10 + band(.flags7, 0xf0)
				@_ntMirroring = band(.flags6, 0x09)
				@_system = (band(.system_type, 0x03) == 0x02 or band(.system_type, 0x01) == 0x01) and 'PAL' or 'NTSC'
				@_trainer = band(.flags6, 0x04) == 0x04

		ines2: (header) =>
			with header
				@_prgROMSize = (.prg_rom_size_lsb + band(.rom_size_msb, 0x0f) * 0x100) * 16384
				@_chrROMSize = (.chr_rom_size_lsb + band(.rom_size_msb, 0xf0) / 0x10) * 8192
				@_prgRAMSize = .prg_ram_size > 0 and .prg_ram_size * 8192 or 8192
				@_chrRAMSize = .chr_ram_size * 8192
				@_mapperId = band(.flags6, 0xf0) / 0x10 + band(.flags7, 0xf0)
				@_ntMirroring = band(.flags6, 0x09)
				@_system = (band(.system_type, 0x03) == 0x02 or band(.system_type, 0x01) == 0x01) and 'PAL' or 'NTSC'
				@_trainer = band(.flags6, 0x04) == 0x04
	}
