use JSON;
my %pintypes=('IN' => 'input', 'OUT' => 'output');

die "Usage: perl $0 <.esym file name> <output filename or - (STDOUT) or empty (use symbol name)>\n" if $#ARGV<0;
die "File '$ARGV[0]' is not found\n" unless open F, "<$ARGV[0]";
$symb=from_json('['.join(',', <F>).']');
close F;
#get all parts 
my @parts;
foreach (@$symb) {
  push @parts, [] if $_->[0] eq 'PART';
  push @{$parts[-1]}, $_ if $#parts>=0;
}
#get symbol name (but there's only part name in file, so the first part name is adopted)
my $name=$parts[0]->[0]->[1]=~s/[\-#\$_\.:,\]\d*$//r;
unless ($#ARGV>0 && $ARGV[0] eq '-') {
  $#ARGV>0 &&  (open STDOUT,">$ARGV[1]" or die "Failed to open '$ARGV[1]' for writing\n") or
  open STDOUT, ">$name.kicad_sym" or
  open STDOUT, '>'.($ARGV[0]=~s/\.[^\.]*$//r).'.kicad_sym'
  or die "Failed to open '".($ARGV[0]=~s/\.[^\.]*$//r).".kicad_sym' for writing\n";
}
#start too write header
print  <<"EOF";
(kicad_symbol_lib (version 20220914) (generator esym2kicad_pl)
  (symbol "$name" (in_bom yes) (on_board yes)
    (property "Reference" "${\map {split /\?$/, $_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Designator' } @$symb}" (at 5.08 -6.35 0)
      (effects (font (size 1.27 1.27)) (justify left))
    )
    (property "Value" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Symbol' } @$symb}" (at 5.08 -8.89 0)
      (effects (font (size 1.27 1.27)) (justify left))
    )
    (property "Footprint" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Footprint' } @$symb}" (at 0 0 0)
      (effects (font (size 1.27 1.27)) hide)
    )
    (property "Datasheet" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'link' } @$symb}" (at 0 0 0)
      (effects (font (size 1.27 1.27)) hide)
    )
EOF
#do every parts
my $part_suffix=1;
foreach my $part(@parts) {
  print  <<"EOF"; # there seems to be a rule about symbol's name, which is not compatible with LcEDA
    (symbol "${name}_${\$part_suffix++}_1"
EOF
  #["RECT","e3",-60,-55,60,55,0,0,0,"st1",0]
  foreach (grep {$_->[0] eq 'RECT'} @$part) {
    print <<"EOF";
      (rectangle (start ${\($_->[2]*0.254)} ${\($_->[3]*0.254)}) (end ${\($_->[4]*0.254)} ${\($_->[5]*0.254)})
        (stroke (width 0) (type default))
        (fill (type none))
      )
EOF
  }
  #["ARC","e14",4.44,-6.9,1.66049,0.08325,4.53,7.03,"st1",0]
  foreach (grep {$_->[0] eq 'ARC'} @$part) {
    print <<"EOF";
      (arc (start ${\($_->[2]*0.254)} ${\($_->[3]*0.254)}) (mid ${\($_->[4]*0.254)} ${\($_->[5]*0.254)}) (end ${\($_->[6]*0.254)} ${\($_->[7]*0.254)})
        (stroke (width 0) (type default))
        (fill (type none))
      )
EOF
  } 
  #["POLY","e11",[-2,8,-2,-8],0,"st1",0]
  foreach (grep {$_->[0] eq 'POLY'} @$part) {
    print <<"EOF";
      (polyline
        (pts
EOF
    my $pts=$_->[2];
     for (my $i=0; $i<$#$pts; $i+=2) {
    print <<"EOF";
          (xy ${\($pts->[$i]*0.254)} ${\($pts->[$i+1]*0.254)})
EOF
    }
    print <<"EOF";
        )
        (stroke (width 0) (type default))
        (fill (type none))
      )
EOF
  } 
  #["CIRCLE","e4",-55,50,1.5,"st1",0]
  foreach (grep {$_->[0] eq 'CIRCLE'} @$part) {
    print  <<"EOF";
      (circle (center ${\($_->[2]*0.254)} ${\($_->[3]*0.254)}) (radius ${\($_->[4]*0.254)})
        (stroke (width 0) (type default))
        (fill (type none))
      ) 
EOF
  } 
  #["PIN","e5",1,1,-70,45,10,0,null,0,0,1]
  #["ATTR","e6","e5","NAME","VSS",false,true,-56.3,39.08502,0,"st4",0]
  #["ATTR","e7","e5","NUMBER","1",false,true,-60.5,44.08502,0,"st5",0]
  #["ATTR","e8","e5","Pin Type","IN",false,false,-70,45,0,"st2",0]
  foreach (grep {$_->[0] eq 'PIN'} @$part) {
    my $id=$_->[1];
    print  <<"EOF";
      (pin ${\($pintypes{(map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[2] eq $id && $_->[3] eq 'Pin Type'} @$part)[0]} ||  'passive')} line (at ${\($_->[4]*0.254)} ${\($_->[5]*0.254)} $_->[7]) (length ${\($_->[6]*0.254)})
        (name "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[2] eq $id && $_->[3] eq 'NAME' } @$part}")
        (number "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[2] eq $id && $_->[3] eq 'NUMBER' } @$part}"\)
      )
EOF
  } 
  #["TEXT","e313",908,160,0,"yyy","st4",0]
  #["FONTSTYLE","st4",null,null,"Times new roman",15,0,0,0,null,1,0]
  foreach (grep {$_->[0] eq 'TEXT'} @$part) {
    my $id=$_->[1];
    my $style=$_->[6];
    print  <<"EOF";
      (text "$_->[5]" (at ${\($_->[2]*0.254)} ${\($_->[3]*0.254)} $_->[4])
        (effects (font (size ${\map {$_->[5]*0.254} grep {$_->[0] eq 'FONTSTYLE' && $_->[1] eq $style} @$part} ${\map {$_->[5]*0.254} grep {$_->[0] eq 'FONTSTYLE' && $_->[1] eq $style} @$symb})))
      )
EOF
  } 
print  <<"EOF";
    )
EOF
}
print  <<"EOF";
  )
)
EOF

close STDOUT;