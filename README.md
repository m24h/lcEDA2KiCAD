# lcEDA2KiCAD
Migrate data from LcEDA to KiCAD by perl scripts

Only symbols/schematics are supported to be convert now.
Note It can't be perfect.
Footprints, and PCB are not supported.

## elib2efoos.pl
This script extracts all footprints from .elib .eprj file, to .efoo files (one file per footprint).

## elib2esyms.pl
This script extracts all symbols from .elib .eprj file, to .esym files (one file per symbol).

## eprj2dir.pl
This script extracts Schematics/PCBs/Symbols/Footprints/Devices from a .eprj file (file to store a LcEDA project), to a new directory with same name (without extension).

## esch2kicad.pl
This script converts LcEDA .esch file to kiCAD .kicad_sch file, it also need other files created by eprj2dir.pl.
It's now experimental, still requires a lot of manual modifications for the final schematics.
Maybe some .esym files are reported not found, those are the fake components (GND/VCC ...) that are lacking, I tried my best to restore them.

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
6. You got your library "mylib.kicad_sym", but be careful not to put it in library repeatedly if you want to do step 5 again.

## How to convert a lcEDA schematics to kiCAD in windows prompt :
1. Get the .eprj file, for example, "xxx.eprj".
2. perl eprj2dir.pl xxx.eprj
3. A directory "xxx" is created, which contains useful files, including schematics files, for example, "yyy.esch".
4. Make sure esym2kicad.pl is in current directory too, or you can copy it there.
5. perl esch2kicad.pl xxx\yyy.esch
6. You got your "yyy.kicad_sch", check it manually and carefully.
