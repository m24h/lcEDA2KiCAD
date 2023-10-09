# lcEDA2KiCAD
Migrate data from LcEDA to KiCAD by perl scripts

Script files is simple and short and useful. 
Running without arguments will give some hints.
Only symbols are supported to be convert now. Footprints, schematics and PCB are not supported (I think that footprints are already almost all standardized, and automatic migration will not be good for latter two). 

## elib2efoos.pl
This script extracts all footprints from .elib .eprj file, to .efoo files (one file per footprint).

## elib2esyms.pl
This script extracts all symbols from .elib .eprj file, to .esym files (one file per symbol).

## esym2kicad.pl
This script converts LcEDA .esym file to kiCAD .kicad_sym file, supports multi-units, rectangles, polylines, circles, arcs, texts, pins.

## eprj2dir.pl
This script extracts Schematics/PCBs/Symbols/Footprints/Devices from a .eprj file (file to store a LcEDA project), to a new directory with same name (without extension).

## mksymlib.pl
This script merges multiple .kicad_sym file (with one symbol in it) to a single .kicad_sym file (now it contains many symbols and becomes a libaray).



