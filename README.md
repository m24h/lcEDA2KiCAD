# lcEDA2KiCAD
Migrate data from LcEDA to KiCAD by perl scripts

Script files is simple and short and useful. 
Running without arguments will give some hints.
Only symbols are supported to be convert now. Footprints, schematics and PCB are not supported (I think that footprints are already almost all standardized, and automatic migration will not be good for latter two). 

## elib2efoos.pl
This script extracts all footprints from .elib .eprj file, to .efoo files (one file per footprint).

## elib2esyms.pl
This script extracts all symbols from .elib .eprj file, to .esym files (one file per symbol).

## eprj2dir.pl
This script extracts Schematics/PCBs/Symbols/Footprints/Devices from a .eprj file (file to store a LcEDA project), to a new directory with same name (without extension).

## esch2kicad.pl
This script converts LcEDA .esch file to kiCAD .kicad_sch file, it also need other files created by eprj2dir.pl.
It's now experimental, still requires a lot of manual modifications for the final schematics.
Some .esym files are reported not found, those are the fake components (GND/VCC ...) that are lacking, NET labels are leaved there instead.

## esym2kicad.pl
This script converts LcEDA .esym file to kiCAD .kicad_sym file, supports multi-units, rectangles, polylines, circles, arcs, texts, pins.

## mksymlib.pl
This script merges multiple .kicad_sym file (with one symbol in it) to a single .kicad_sym file (now it contains many symbols and becomes a libaray).

## How to convert standard symbol lib from lcEDA to kiCAD in windows prompt :
1. Make a new directory, for example, "xxx\dir1".
2. cd xxx\dir1
3. perl elib2esyms.pl yyy\lcedapro\resources\app\assets\db\lceda-std.elib
4. for %f in (*.esym) do perl esym2kicad.pl %f
5. perl mksymlib.pl mylib.kicad_sym *.kicad_sym
6. You got you library "mylib.kicad_sym", but be careful not to put it in library repeatedly if you want to do step 5 again.

