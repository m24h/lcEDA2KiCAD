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
#["FONTSTYLE","st4",null,null,"Times new roman",15,0,0,0,null,1,0]
my %fonts=map {$_->[1] => $_->[5] && '(font (size '.($_->[5]*0.254).' '.($_->[5]*0.254).'))' || ''} grep {$_->[0] eq 'FONTSTYLE'} @$symb;
#["LINESTYLE","st19",null,3,"#330033",null]
my %linestyles=map {$_->[1] => '(stroke (width '. ($_->[5]*0.254 || 0).') (type '.($_->[3] && qw(solid dash dot dash_dot)[$_->[3]] || 'default').')'
                                                  .($_->[2]=~/#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])/i && " (color ${\hex($1)} ${\hex($2)} ${\hex($3)} 1)" || '').')'
                                                  .($_->[4]=~/#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])/ && " (fill (type color) (color ${\hex($1)} ${\hex($2)} ${\hex($3)} 1))" || ' (fill (type none))')}
                         grep {$_->[0] eq 'LINESTYLE'} @$symb;
#get symbol name (but there's only part name in file, so the first part name is adopted)
my $name=$parts[0]->[0]->[1]=~s/[\-#\$_\.:,]\d*$//r;
unless ($#ARGV>0 && $ARGV[0] eq '-') {
  $#ARGV>0 &&  (open STDOUT,">$ARGV[1]" or die "Failed to open '$ARGV[1]' for writing\n") or
  open STDOUT, ">$name.kicad_sym" or
  open STDOUT, '>'.($ARGV[0]=~s/\.[^\.]*$//r).'.kicad_sym'
  or die "Failed to open '".($ARGV[0]=~s/\.[^\.]*$//r).".kicad_sym' for writing\n";
}
#start to write header
print  <<"EOF";
(kicad_symbol_lib (version 20220914) (generator esym2kicad_pl)
  (symbol "$name" (in_bom yes) (on_board yes)
    (property "Reference" "${\map {split /\?$/, $_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Designator' } @$symb}" (at -5.08 6.35 0)
      (effects (justify left))
    )
    (property "Value" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Symbol' } @$symb}" (at -5.08 8.89 0)
      (effects (justify left))
    )
    (property "Footprint" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Footprint' } @$symb}" (at 0 0 0)
      (effects hide)
    )
    (property "Datasheet" "${\map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'link' } @$symb}" (at 0 0 0)
      (effects  hide)
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
        $linestyles{$_->[9]}
      )
EOF
  }
  #["ARC","e14",4.44,-6.9,1.66049,0.08325,4.53,7.03,"st1",0]
  foreach (grep {$_->[0] eq 'ARC'} @$part) {
    eval {  # will fail if 3 points is in a line
      # can't believe that kiCAD does not support arcs with angles >180 degree, so hard to fix it
      my ($x1,$y1,$x2,$y2,$x3,$y3)=($_->[2]*0.254,$_->[3]*0.254,$_->[4]*0.254,$_->[5]*0.254,$_->[6]*0.254,$_->[7]*0.254);
      my ($x21,$x32,$x13,$y21,$y32,$y13)=($x2-$x1,$x3-$x2,$x1-$x3,$y2-$y1,$y3-$y2,$y1-$y3);
      my ($a,$b)=($x21*$y32-$y21*$x32, $x21*$y13-$y21*$x13);  # 0 means 3 points is in a line
      my ($c,$d)=($x1*$x1+$y1*$y1-$x2*$x2-$y2*$y2, $x1*$x1+$y1*$y1-$x3*$x3-$y3*$y3);
      my ($x0,$y0)=(-($y13*$c+$y21*$d)/$b/2, ($x21*$d+$x13*$c)/$b/2);
      my ($s1,$s3,$pi2)=(atan2($y1-$y0,$x1-$x0), atan2($y3-$y0,$x3-$x0), 4*atan2(1,0));
      my $ang=$a>0?($s3-$s1):($s1-$s3); $ang+=$pi2 if ($ang<0); #CCW running angle
      if ($ang>3.14) { # have to split it
        my $r=sqrt(($x1-$x0)*($x1-$x0)+($y1-$y0)*($y1-$y0));
        my ($x4,$y4)=($x0+$r*cos($s1+$ang/2), $y0+$r*sin($s1+$ang/2));
        my ($x5,$y5)=($x0+$r*cos($s1+$ang/4), $y0+$r*sin($s1+$ang/4));
        my ($x6,$y6)=($x0+$r*cos($s3-$ang/4), $y0+$r*sin($s3-$ang/4));
        print <<"EOF";
      (arc (start $x1 $y1) (mid $x5 $y5) (end $x4 $y4)
        $linestyles{$_->[8]}
      )
      (arc (start $x4 $y4) (mid $x6 $y6) (end $x3 $y3)
        $linestyles{$_->[8]}
      )
EOF
      } else {
        print <<"EOF";
      (arc (start $x1 $y1) (mid $x2 $y2) (end $x3 $y3)
        $linestyles{$_->[8]}
      )
EOF
      }
    };
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
        $linestyles{$_->[4]}
      )
EOF
  } 
  #["BEZIER","e211",[-140,-20,-120,0,-90,0,-80,-10],"st1",0], not supported, just take a pose
  foreach (grep {$_->[0] eq 'BEZIER'} @$part) {
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
        $linestyles{$_->[3]}
      )
EOF
  } 
  #["CIRCLE","e4",-55,50,1.5,"st1",0]
  foreach (grep {$_->[0] eq 'CIRCLE'} @$part) {
    print  <<"EOF";
      (circle (center ${\($_->[2]*0.254)} ${\($_->[3]*0.254)}) (radius ${\($_->[4]*0.254)})
        $linestyles{$_->[5]}
      ) 
EOF
  } 
  #["ELLIPSE","e206",-100,20,10,20,0,"st1",0], not supported, just take a pose
   foreach (grep {$_->[0] eq 'ELLIPSE'} @$part) {
    print  <<"EOF";
      (circle (center ${\($_->[2]*0.254)} ${\($_->[3]*0.254)}) (radius ${\(($_->[4]+$_->[5])*0.127)})
        $linestyles{$_->[7]}
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
  foreach (grep {$_->[0] eq 'TEXT'} @$part) {
    my $id=$_->[1];
    my $style=$_->[6];
    print  <<"EOF";
      (text "$_->[5]" (at ${\($_->[2]*0.254)} ${\($_->[3]*0.254)} ${\($_->[4]*10)})
        (effects $fonts{$_->[6]})
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
