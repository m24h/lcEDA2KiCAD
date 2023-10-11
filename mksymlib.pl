die <<"EOF" if $#ARGV<0;
Usage: perl $0 <output file name or '-' (STDOUT)> <input file names, * can be used>
  Specified .kicad_sym file (which should be created by esym2kicad.pl) will be packed into a signle lib file.
  Example : perl $0 abc.kicad_sym xyz/*.kicad_sym def.kicad_sym
EOF
die "Unable to open '$ARGV[0]'\n" unless open STDOUT,">$ARGV[0]";
undef  $/;
print  <<"EOF";
(kicad_symbol_lib (version 20220914) (generator makekicadlib_pl)
EOF
foreach (grep {!-d $_ && -e $_ && !/^\./ } glob join(' ',@ARGV[1..$#ARGV])) {
	print STDERR "processing $_\n";
	next unless open T, "<$_";
	$_=<T>;
	close T;
	print "  $1\n" if /(\(\s*symbol\s(.|\n)*?)(\s|\n)*\)[^\)]*$/i;
}
print  <<"EOF";
)
EOF
close STDOUT;