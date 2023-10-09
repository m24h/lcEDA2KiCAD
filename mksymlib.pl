die "Usage: perl $0 <.output file name or '-' (STDOUT)>\n\t\All .kicad_sym file (which should be created by esym2kicad.pl) will be packed to a signle lib file\n" if $#ARGV<0;
die "Unable to open '$ARGV[0]'\n" unless $ARGV[0] eq '-' || open STDOUT,">$ARGV[0]";
undef  $/;

print  <<"EOF";
(kicad_symbol_lib (version 20220914) (generator makekicadlib_pl)
EOF
foreach (grep {!-d $_ && -e $_ && !/^\./ } <'*.kicad_sym'>) {
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