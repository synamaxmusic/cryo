# Cryo Image Ripper by SynaMax
# First successful parsing on April 16, 2024
# PNG export completed on September 6th, 2025
#
# Supports un-HSQ'd MegaRace sprites and palettes
# Also supports Dune however palettes will need to be offset slightly to work

extends Node2D

# We need these to convert signed bytes into negative numbers
const MAX_7B = 1 << 7
const MAX_8B = 1 << 8

var image = [] # Holds offset table
var index = 0
var rle = FileAccess.open("res://data/_HOO.___", FileAccess.READ)
var savename = rle.get_path()
var byte_count = 0
var palette = PackedByteArray()
@export var palarray: Array[Color]

var underscore_palette : bool = false

var colors : FileAccess

var offset = rle.get_16() # Offset Table address
var paloff = rle.get_8() # Palette group start
var paloff2 = rle.get_8() # Number of colors in palette group

var header_byte = rle.get_8()
var header_data = rle.get_8()
var header_conv = unsigned8_to_signed(header_byte)

var width = null
var compress_bit = null
var height = null
var palette_offset = null

var palette_index : int = 0
var palnum = 9


func unsigned8_to_signed(unsigned):
	return (unsigned + MAX_7B) % MAX_8B - MAX_7B


# Called when the node enters the scene tree for the first time.
func _ready():
	image_check()
	palette_parse()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func load_file():
	print("Opening file...Parsing Header")

	rle.seek(offset) # Go to offset table
	var frame1 = rle.get_16() # First image start address
	var offend = offset+frame1 # End of offset table	
	
	rle.seek(offset) # Go to offset table again
	var line = rle.get_16() # Grab first offset
	image = [line] # Add offset address to array
	
	while rle.get_position() < offend: # Keep doing this until you're at the end of table
		line = rle.get_16()	# Grab two bytes
		image.push_back(line) # Add it to the array
	print(image)
	

	for x in (image.size()):
		var filesize = rle.get_length()-offset
		var savedata = FileAccess.open(savename.get_basename()+str(x)+".bin", FileAccess.WRITE)
		var start = x # Starting address for image
		var end = x # Second address
		index = x

		if x+1 < image.size(): # Check to make sure we don't go out of bounds with array
			end = x+1
		else:
			image.push_back(filesize)
			end = x+1
		if image[start] < image[end]: #If addresses are not the same, then proceed
			rle.seek((offset+image[start]))
			width = rle.get_8() 
			compress_bit = rle.get_8() #If Image width is over 0xFF, then overflow happens here
			height = rle.get_8()
			palette_offset = rle.get_8()
			#print("Current Position: "+str(rle.get_position()))

			header_byte = rle.get_8()
			header_data = rle.get_8()
			header_conv = unsigned8_to_signed(header_byte)


			while rle.get_position() < offset+image[end]:
				if header_byte & 0x80:
					#print("Header byte is signed ",header_conv)
					header_conv = -header_conv+1 
					for n in header_conv:
						savedata.store_8(header_data)
				#print("Wrote: ",header_data," ",header_conv," times")
					header_byte = rle.get_8()
					header_data = rle.get_8()
					header_conv = unsigned8_to_signed(header_byte)
				else:
					#print("Header byte is unsigned ",header_byte)
					#header_byte = header_byte+1
					savedata.store_8(header_data)
					for n in header_byte:
						header_data = rle.get_8()
						savedata.store_8(header_data)
						#print("Wrote: ",header_data)
					header_byte = rle.get_8()
					header_data = rle.get_8()
					header_conv = unsigned8_to_signed(header_byte)
			savedata.close()
			save_png()
	print("<<< Sprites extracted! >>>")

func image_check():
	# There are several different types of MegaRace sprites:
	#
	# - Normal sprites have palettes before graphics data and are RLE-encoded.
	# - Special effects like "fumee" don't have a palette and require the explosion colors.
	# - Opponents have uncompressed graphics first with 8 fixed-size palette chunks after.
	#
	# Because other sprites rely on the explosion palette, it's a good idea to extract
	# that sprite first before extracting the graphics in "fumee".
	
	var underscore_check = savename.get_file()

	if offset == 2:
		print("<<< No palette defined! >>>")
	
	if underscore_check.begins_with("_"):
		print("<<< Opponent car sprite detected >>>")
		print("<<< Grabbing palettes for uncompressed sprites >>>")
		underscore_palette = true

func palette_parse():

	if underscore_palette:
		underscore_palette_parse()
		return

	if offset == 2:
		print("<<< Skipping palette parsing! >>>")
		load_file()
		return

	rle.seek(2)
	var palgroup = rle.get_8()
	var palcount = rle.get_8()
	var palstart = rle.get_position()
	var palbyte = palcount * 3

	var savedata = FileAccess.open(savename.get_basename()+".pal", FileAccess.WRITE_READ)
	
	#while rle.get_position() < rle.get_position()+palbyte:
	while palgroup != palcount:
		if palgroup != 0xFF:
			for x in palbyte:
					savedata.seek((palgroup*3)+x)
					rle.seek(palstart+x)
					#print(rle.get_position())
					savedata.store_8((rle.get_8()<<2)) # bitshift here
					#palette.encode_u8(palgroup,palcolor)
					
			if rle.get_position() < offset:
				#print(rle.get_position())
				palgroup = rle.get_8()
				palcount = rle.get_8()
				palstart = rle.get_position()
				palbyte = palcount*3
		else:
			print("<<< Palette extracted! >>>")
			savedata.close()
			break
	savedata.close()
	load_file()
	#print(savename.get_basename()+str(index)+".bin")

func underscore_palette_parse():
	print("<<< Attempting palette rip from uncompressed '_XXX.HSQ' MegaRace sprite >>>")
	rle.seek_end(-1755)
	var palsize = 0xC3

	var filesize = rle.get_length()
	
	palette.resize(0x23A)
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
		savedata.close()
	underscore_gfx()

func underscore_gfx():
	print("Opening special file...Parsing Uncompressed Sprite Header")
	rle.seek(offset) # Go to offset table
	var frame1 = rle.get_16() # First image start address
	var offend = offset+frame1 # End of offset table	
	
	rle.seek(offset) # Go to offset table again
	var line = rle.get_16() # Grab first offset
	image = [line] # Add offset address to array
	
	while rle.get_position() < offend: # Keep doing this until you're at the end of table
		line = rle.get_16()	# Grab two bytes
		image.push_back(line) # Add it to the array
	
	# The last 9 entries are the palettes themselves, so we don't need those.
	# We will keep the last one so we can get the image size
	image.resize(12)
	print(image)

	# There are 11 uncompressed images for the opponents
	for x in 11:
		var filesize : int
		var savedata = FileAccess.open(savename.get_basename()+str(x)+".bin", FileAccess.WRITE)
		var start = x # Starting address for image
		var end = x # Second address
		index = x

		if image[start] < image[11]: #If addresses are not the same, then proceed
			rle.seek((offset+image[start]))
			width = rle.get_8() 
			compress_bit = rle.get_8() #If Image width is over 0xFF, then overflow happens here
			height = rle.get_8()
			palette_offset = rle.get_8()
			
			filesize = width * height
			
			header_data = rle.get_buffer(filesize)
			savedata.store_buffer(header_data)
			savedata.close()
			
			for i in range(palnum):
				palette_index = i
				save_png()

func save_png():
	palarray = []
	if offset == 2:
		# force use of explosion sprite color palette (good idea to extract this first)
		colors = FileAccess.open("res://data/explose.pal", FileAccess.READ)
	else:
		colors = FileAccess.open(savename.get_basename()+".pal", FileAccess.READ)

	if underscore_palette:
		colors = FileAccess.open(savename.get_basename()+str(palette_index)+".pal", FileAccess.READ)

	for n in 256:
		palarray.push_back(Color.from_rgba8((colors.get_8()),(colors.get_8()),(colors.get_8()),255))
	
	var bindata = FileAccess.get_file_as_bytes(savename.get_basename()+str(index)+".bin")
	var binsize = bindata.size()
	var binimage = Image.create(width,height,false,Image.FORMAT_RGBA8)
	var byte : int
	var imagebyte : Color

	for y in range(height):
		for x in range(width):
			byte=width*y+x;
			if((byte>=0)&&(byte<binsize)):
				#get color from color table
				imagebyte=palarray[(bindata[byte])]
				binimage.set_pixel(x, y, imagebyte)
			else:
				imagebyte=Color.BLACK
				binimage.set_pixel(x, y, imagebyte)

	$Sprite2D.texture = ImageTexture.create_from_image(binimage)
	binimage.save_png(savename.get_basename()+str(index)+"_PAL"+str(palette_index)+".png")
