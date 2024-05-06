# Cryo Palette Extractor by SynaMax
#
# For use on non-RLE '_XXX.HSQ' MegaRace sprites
#
# Unlike the regular car sprites, these "underscore" sprites are not encoded
# with RLE and can be viewed in TiledGGD as raw data.
# These images also use a different file structure compared to the regular 
# MegaRace sprites so this script just extracts the palettes found at the end
# of the file and converts them into usable palettes for TiledGGD.
#
# Opponent car sprite palettes are offset to 0xC6

extends Node

var rle = FileAccess.open("res://data/_luf.xxx", FileAccess.READ) # Change filename here!
var savename = rle.get_path()
var byte_count = 0
var palette = PackedByteArray()

var offset = rle.get_16() # Offset Table address

# Called when the node enters the scene tree for the first time.
func _ready():
	palette_parse()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func palette_parse():
	if offset == 2:
		print("<<< No palette defined! >>>")
		print("<<< Attempting palette rip from uncompressed '_XXX.HSQ' MegaRace sprite >>>")
	rle.seek_end(-1755)
	var palsize = 0xC3
	var palnum = 8
	var filesize = rle.get_length()
	
	palette.resize(256*3)
	palette.fill(0)

	#while rle.get_position() < filesize:
	for y in palnum:
		var savedata = FileAccess.open(savename.get_basename()+str(y)+".pal", FileAccess.WRITE_READ)
		savedata.store_buffer(palette)
		for x in palsize:
	
					#savedata.seek((palgroup*3)+x)
					#rle.seek(palstart+x)
					#print(rle.get_position())
					savedata.store_8((rle.get_8()<<2)) # bitshift here
					#palette.encode_u8(palgroup,palcolor)
					
#			if rle.get_position() < offset:
				#print(rle.get_position())

		print("<<< Palette extracted! >>>")
#			break
