# Cryo Image Ripper by SynaMax
# Completed on April 16, 2024
#
# Supports un-HSQ'd MegaRace sprites and palettes
# Also supports Dune however palettes will need to be offset slightly to work

extends Node

# We need these to convert signed bytes into negative numbers
const MAX_7B = 1 << 7
const MAX_8B = 1 << 8

var image = [] # Holds offset table
var index : = 1
var save_image = FileAccess.open("res://image_offset_table.bin", FileAccess.WRITE)
var rle = FileAccess.open("res://data/ou_a.___", FileAccess.READ) # Change filename here!
var savename = rle.get_path()
var byte_count = 0
var palette = PackedByteArray()

var offset = rle.get_16() # Offset Table address
var paloff = rle.get_8() # Palette group start
var paloff2 = rle.get_8() # Number of colors in palette group

var header_byte = rle.get_8()
var header_data = rle.get_8()
var header_conv = unsigned8_to_signed(header_byte)


func unsigned8_to_signed(unsigned):
	return (unsigned + MAX_7B) % MAX_8B - MAX_7B

# Called when the node enters the scene tree for the first time.
func _ready():
	load_file()
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
	var count = 0
	image = [line] # Add offset address to array
	save_image.store_16(line) # Save the bytes to the file too
	
	while rle.get_position() < offend: # Keep doing this until you're at the end of table
		line = rle.get_16()	# Grab two bytes
		image.push_back(line) # Add it to the array
		count += 1
		save_image.store_16(line) # Save again
	save_image.close()
	print(image)
	

	for x in (image.size()):
		var filesize = rle.get_length()-offset
		var savedata = FileAccess.open(savename.get_basename()+str(x)+".bin", FileAccess.WRITE)
		var start = x # Starting address for image
		var end = x # Second address

		if x+1 < image.size(): # Check to make sure we don't go out of bounds with array
			end = x+1
		else:
			image.push_back(filesize)
			end = x+1
		if image[start] < image[end]: #If addresses are not the same, then proceed
			rle.seek((offset+image[start]+4))
			#print("Current Position: "+str(rle.get_position()))

			header_byte = rle.get_8()
			header_data = rle.get_8()
			header_conv = unsigned8_to_signed(header_byte)
			
				#while rle.get_position() < image[1]:
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
	print("<<< Sprites extracted! >>>")


func palette_parse():
	if offset == 2:
		print("<<< No palette defined! >>>")
		return
	rle.seek(2)
	var palgroup = rle.get_8()
	var palcount = rle.get_8()
	var palstart = rle.get_position()
	var palcolor = rle.get_8()
	var palbyte = palcount*3
	palette.resize(256*3)
	palette.fill(0)
	var savedata = FileAccess.open(savename.get_basename()+".pal", FileAccess.WRITE_READ)
	
	savedata.store_buffer(palette)
	
	while rle.get_position() < rle.get_position()+palbyte:
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
				palcolor = rle.get_8()
				palbyte = palcount*3
		if palgroup == 0xFF:
			print("<<< Palette extracted! >>>")
			break
