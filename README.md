# CalVM (Preview)

This is an implementation of the [CalVM](https://github.com/callisto-lang/calvm) virtual machine specification from the [Callisto](https://callisto.mesyeti.uk/) language project. CalVM's design has not yet been finalised, so this could all stop working tomorrow, but this project serves as a test of the concept to see what parts of the spec could use attention.

## Implementation Details

64KiB of RAM, up to 4GiB of ROM, 256 word data and return stacks.

Extension Calls:
- **print_ch**: Print an ASCII character.
- **print_int**: Print an integer.
- **print_int_s**: Print a signed integer.

## .cvm format

CalVM has separate address spaces for program code and data, so for the binary format I load, I needed a way to define initial contents for both sections. The .cvm format is pretty much the simplest format I could think of for this purpose:

Offset             | Size      | Description
------------------ | --------- | -----------
0                  | 4         | code_size = Size of the code section
4                  | 4         | data_size = Size of the data section
8                  | code_size | Code section
8 + code_size      | data_size | Data section

The size fields are stored in little-endian, to match CalVM's encoding.

## Assembler

I created an assembler for CalVM based on a few Discord messages showing Yeti's planned syntax. It probably won't match with the final CalVM assembly language, but in the absence of an official spec, it'll do.

Run it as `python asm.py input.asm output.cvm`. Read the source to understand the syntax.
