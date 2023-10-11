use JSON;
die <<"EOF" if $#ARGV<0;
Usage: perl $0 <.esch file name> <output filename or - (STDOUT) or empty (use same name)>
	This .esch file depends on devices.json and .esym .ersc files, which are extracted by eprj2dir.pl.
	Therefore, those files should be kept in the same directory as .esch file when using this script.
	Also, esym2kicad.pl is needed/called, it should be put into the same directory as this script.
EOF
my $dir=$ARGV[0]=~s/[^\\\/]*$//r;
die "File '$ARGV[0]' is not found\n" unless open F, "<$ARGV[0]";
$sch=from_json('['.join(',', <F>).']');
close F;
#devices.json, created by eprj2dir.pl
print STDERR "Load file '${dir}devices.json'\n";
die "File '${dir}devices.json' is not found\n" unless open F, "<${dir}devices.json";
$dev=from_json(join('', <F>));
close F;
#["FONTSTYLE","st4",null,"#6666FF","Times new roman",15,0,0,0,null,1,0]
my %fonts=map {$_->[1] => '(font'
                              .($_->[5] && ' (size '.($_->[5]*0.127).' '.($_->[5]*0.127).')' || '')
                              .($_->[7] && ' bold' || ''). ($_->[6] && ' italic' || '')
                              .($_->[3]=~/#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])/i && " (color ${\hex($1)} ${\hex($2)} ${\hex($3)} 1)" || '').')'
                              .' (justify '.(defined($_->[11]) && (' left', '', ' right')[$_->[11]] || ' left').(defined($_->[10]) && (' top', '', ' bottom')[$_->[10]] || ' bottom').')'
                     } grep {$_->[0] eq 'FONTSTYLE'} @$sch;
#["LINESTYLE","st19",null,3,"#330033",null]
my %linestyles=map {$_->[1] => '(stroke'. (defined($_->[5]) && '(width '.$_->[5]*0.254.')' || '').' (type '.(defined($_->[3]) && qw(solid dash dot dash_dot)[$_->[3]] || 'default').')'
                                                  .($_->[2]=~/#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])/i && " (color ${\hex($1)} ${\hex($2)} ${\hex($3)} 1)" || '').')'
                                                  .($_->[4]=~/#([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])/ && " (fill (type color) (color ${\hex($1)} ${\hex($2)} ${\hex($3)} 1))" || ' (fill (type none))')
                          } grep {$_->[0] eq 'LINESTYLE'} @$sch;
#print STDERR to_json(\%fonts,{'indent'=>1});
#print STDERR to_json(\%linestyles,{'indent'=>1});
my $ofname=$#ARGV>0 && $ARGV[1] || ($ARGV[0]=~s/^(.*[\\\/])?([^\\\/]*?)(\.[^\.]*)?$/\2/r).'.kicad_sch';
die "Failed to open '$ofname' for writing\n" unless open STDOUT, ">$ofname";
#header, paper size is default A4, which give Y-coordinatem an offset 210.82mm, all offsets must be multiple of 2.54
my $y_off=210.82;
my $x_off=10.16;
print <<"EOF";
(kicad_sch (version 20230121) (generator esch2kicad_pl)
  (title_block
    (title "${\($ofname=~s/\.[^\.]*$//r)}")
  )
EOF
#["COMPONENT","e1271","AS4950.1",220,450,0,0,{},0]
#["ATTR","e1272","e1271","Symbol","af05692b5f354941bea16089a587f2e8",0,0,null,null,0,"st6",0]
#["ATTR","e1273","e1271","Designator","U6",0,1,185,480,0,"st6",0]
#["ATTR","e1288","e1271","Name","={Manufacturer Part}",0,1,185,410,0,"st2",0]
#["ATTR","e1290","e1271","Device","9dcbaa4973194913a7624491953f78c1",0,0,null,null,0,"st5",0]
my %symb;
my $pwrref=0;
foreach (grep {$_->[0] eq 'COMPONENT'} @$sch) {
  my $id=$_->[1];
  my $unit=($_->[2]=~/\.(\d+)\s*$/)?$1:'1';
  my $symbol=(map {$_->[4]} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Symbol' && $_->[2] eq $id} @$sch)[0];
  next unless $symbol;
  my $refer=(grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Designator' && $_->[2] eq $id} @$sch)[0];
  my $device=(map {$dev->{$_->[4]}} grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Device' && $_->[2] eq $id} @$sch)[0];
  my $name=(grep {$_->[0] eq 'ATTR' && $_->[3] eq 'Name' && $_->[2] eq $id} @$sch)[0];
  # default fake components
  if ($device->{'Page Size'}) { # a sheet
    print<<"EOF";
    (paper "$device->{'Page Size'}" )
EOF
    next;
  } elsif ($device->{'Name'} eq 'GND' || $device->{'Global Net Name'} eq 'GND') {
    print<<"EOF";
  (symbol (lib_id "power:GND") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced)
    (property "Reference" "#PWR0${\(++$pwrref)}"
      (effects hide)
    )
    (property "Value" "GND" (at ${\($x_off+$_->[3]*0.254+3.81*sin($_->[5]/180*3.14159265897935))} ${\($y_off-$_->[4]*0.254+3.81*cos($_->[5]/180*3.14159265897935))} 0)
    )
  )
EOF
    next;
  } elsif ($device->{'Name'} eq 'AGND' || $device->{'Global Net Name'} eq 'AGND') {
    print<<"EOF";
  (symbol (lib_id "power:GNDA") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced)
    (property "Reference" "#PWR0${\(++$pwrref)}"
      (effects hide)
    )
    (property "Value" "GNDA" (at ${\($x_off+$_->[3]*0.254+3.81*sin($_->[5]/180*3.14159265897935))} ${\($y_off-$_->[4]*0.254+3.81*cos($_->[5]/180*3.14159265897935))} 0)
    )
  ) 
EOF
    next;
  }  elsif ($device->{'Name'} eq 'VCC' || $device->{'Global Net Name'} eq 'VCC') {
    print<<"EOF";
  (symbol (lib_id "power:VCC") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced)
    (property "Reference" "#PWR0${\(++$pwrref)}"
      (effects hide)
    )
    (property "Value" "VCC" (at ${\($x_off+$_->[3]*0.254-3.81*sin($_->[5]/180*3.14159265897935))} ${\($y_off-$_->[4]*0.254-3.81*cos($_->[5]/180*3.14159265897935))} 0)
    )
  ) 
EOF
    next;
  }  elsif ($device->{'Name'} eq '+5V' || $device->{'Global Net Name'} eq '+5V') {
    print<<"EOF";
  (symbol (lib_id "power:+5V") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced)
    (property "Reference" "#PWR0${\(++$pwrref)}"
      (effects hide)
    )
    (property "Value" "+5V" (at ${\($x_off+$_->[3]*0.254-3.81*sin($_->[5]/180*3.14159265897935))} ${\($y_off-$_->[4]*0.254-3.81*cos($_->[5]/180*3.14159265897935))} 0)
    )
  ) 
EOF
    next;
  }  elsif ($device->{'Name'} eq 'PGND' || $device->{'Global Net Name'} eq 'PGND') {
    print<<"EOF";
  (symbol (lib_id "power:GNDPWR") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit 1)
    (in_bom yes) (on_board yes) (dnp no) (fields_autoplaced)
    (property "Reference" "#PWR0${\(++$pwrref)}"
      (effects hide)
    )
    (property "Value" "GNDPWR" (at ${\($x_off+$_->[3]*0.254+3.81*sin($_->[5]/180*3.14159265897935))} ${\($y_off-$_->[4]*0.254+3.81*cos($_->[5]/180*3.14159265897935))} 0)
    )
  ) 
EOF
    next;
  } 
  #not default power symbol
  unless (exists $symb{$symbol}) {
    $symb{$symbol}={};
    print STDERR "Load '${dir}$symbol.esym'\n";
    if (open F, "perl esym2kicad.pl ${dir}$symbol.esym - |") {
      my $t=join('',<F>);
      close F;
      $symb{$symbol}={'name'=>$2, 'data'=>$1} if $t=~/(\(\s*symbol\s+"([^"]+)"(.|\n)*?)(\s|\n)*\)[^\)]*$/i;
    }
  }
  unless ($symb{$symbol}->{'name'}) { #unknown component
    if ($name->[4]) {
      print STDERR "Unknow symbol '$symbol' '$name->[4]', treat it as a global label\n";
      print <<"EOF";
  (global_label "$name->[4]" (shape input) (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (fields_autoplaced)
    (effects (justify left))
    (property "Intersheetrefs" "${INTERSHEET_REFS}"
      (effects hide)
    )
  )
EOF
    }
    next;   
  }
  print <<"EOF";
  (symbol (lib_id "$symb{$symbol}->{'name'}") (at ${\($x_off+$_->[3]*0.254)} ${\($y_off-$_->[4]*0.254)} $_->[5]) (unit $unit)
    (in_bom yes) (on_board yes) (dnp no)
EOF
  print <<"EOF" if $refer;
    (property "Reference" "$refer->[4]" (at ${\($x_off+$refer->[7]*0.254)} ${\($y_off-$refer->[8]*0.254)} ${\(($refer->[9]-$_->[5]+360)%360)})
      (effects (justify left bottom))
    )
EOF
  if ($name) {
    my $value=$name->[4];
    $value=$device->{$1} if $value=~/=\s*\{\s*(.+?)\s*\}/;
    print <<"EOF";
    (property "Value" "$value" (at ${\($x_off+$name->[7]*0.254)} ${\($y_off-$name->[8]*0.254)} ${\(($name->[9]-$_->[5]+360)%360)})
      (effects (justify left bottom))
    )
EOF
  }
  print <<"EOF" if $device;
   (property "Footprint" "$device->{'Supplier Footprint'}" 
      (effects hide)
    )
  )
EOF
}
#symbol lib
print  <<"EOF";
  (lib_symbols
    (symbol "power:GND" (power) (pin_names (offset 0)) (in_bom yes) (on_board yes)
      (property "Reference" "#PWR" (at 0 -6.35 0)
        (effects hide)
      )
      (property "Value" "GND" (at 0 -3.81 0)
      )
      (property "Footprint" "" (at 0 0 0)
        (effects hide)
      )
      (property "Datasheet" "" (at 0 0 0)
        (effects hide)
      )
      (property "ki_keywords" "global power" (at 0 0 0)
        (effects hide)
      )
      (property "ki_description" "Power symbol creates a global label with name \\"GND\\" , ground" (at 0 0 0)
        (effects hide)
      )
      (symbol "GND_0_1"
        (polyline
          (pts
            (xy 0 0)
            (xy 0 -1.27)
            (xy 1.27 -1.27)
            (xy 0 -2.54)
            (xy -1.27 -1.27)
            (xy 0 -1.27)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
      )
      (symbol "GND_1_1"
        (pin power_in line (at 0 0 270) (length 0) hide
          (name "GND")
          (number "1")
        )
      )
    )
    (symbol "power:+5V" (power) (pin_names (offset 0)) (in_bom yes) (on_board yes)
      (property "Reference" "#PWR" (at 0 -3.81 0)
        (effects hide)
      )
      (property "Value" "+5V" (at 0 3.556 0)
      )
      (property "Footprint" "" (at 0 0 0)
        (effects hide)
      )
      (property "Datasheet" "" (at 0 0 0)
        (effects hide)
      )
      (property "ki_keywords" "global power" (at 0 0 0)
        (effects hide)
      )
      (property "ki_description" "Power symbol creates a global label with name \\"+5V\\"" (at 0 0 0)
        (effects hide)
      )
      (symbol "+5V_0_1"
        (polyline
          (pts
            (xy -0.762 1.27)
            (xy 0 2.54)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0 0)
            (xy 0 2.54)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0 2.54)
            (xy 0.762 1.27)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
      )
      (symbol "+5V_1_1"
        (pin power_in line (at 0 0 90) (length 0) hide
          (name "+5V")
          (number "1")
        )
      )
    ) 
    (symbol "power:GNDA" (power) (pin_names (offset 0)) (in_bom yes) (on_board yes)
      (property "Reference" "#PWR" (at 0 -6.35 0)
        (effects hide)
      )
      (property "Value" "GNDA" (at 0 -3.81 0)
      )
      (property "Footprint" "" (at 0 0 0)
        (effects hide)
      )
      (property "Datasheet" "" (at 0 0 0)
        (effects hide)
      )
      (property "ki_keywords" "global power" (at 0 0 0)
        (effects hide)
      )
      (property "ki_description" "Power symbol creates a global label with name \\"GNDA\\" , analog ground" (at 0 0 0)
        (effects hide)
      )
      (symbol "GNDA_0_1"
        (polyline
          (pts
            (xy 0 0)
            (xy 0 -1.27)
            (xy 1.27 -1.27)
            (xy 0 -2.54)
            (xy -1.27 -1.27)
            (xy 0 -1.27)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
      )
      (symbol "GNDA_1_1"
        (pin power_in line (at 0 0 270) (length 0) hide
          (name "GNDA")
          (number "1")
        )
      )
    )
    (symbol "power:GNDPWR" (power) (pin_names (offset 0)) (in_bom yes) (on_board yes)
      (property "Reference" "#PWR" (at 0 -5.08 0)
        (effects hide)
      )
      (property "Value" "GNDPWR" (at 0 -3.302 0)
      )
      (property "Footprint" "" (at 0 -1.27 0)
        (effects hide)
      )
      (property "Datasheet" "" (at 0 -1.27 0)
        (effects hide)
      )
      (property "ki_keywords" "global ground" (at 0 0 0)
        (effects hide)
      )
      (property "ki_description" "Power symbol creates a global label with name \\"GNDPWR\\" , global ground" (at 0 0 0)
        (effects hide)
      )
      (symbol "GNDPWR_0_1"
        (polyline
          (pts
            (xy 0 -1.27)
            (xy 0 0)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy -1.016 -1.27)
            (xy -1.27 -2.032)
            (xy -1.27 -2.032)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy -0.508 -1.27)
            (xy -0.762 -2.032)
            (xy -0.762 -2.032)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0 -1.27)
            (xy -0.254 -2.032)
            (xy -0.254 -2.032)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0.508 -1.27)
            (xy 0.254 -2.032)
            (xy 0.254 -2.032)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 1.016 -1.27)
            (xy -1.016 -1.27)
            (xy -1.016 -1.27)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 1.016 -1.27)
            (xy 0.762 -2.032)
            (xy 0.762 -2.032)
            (xy 0.762 -2.032)
          )
          (stroke (width 0.2032) (type default))
          (fill (type none))
        )
      )
      (symbol "GNDPWR_1_1"
        (pin power_in line (at 0 0 270) (length 0) hide
          (name "GNDPWR")
          (number "1")
        )
      )
    )
    (symbol "power:VCC" (power) (pin_names (offset 0)) (in_bom yes) (on_board yes)
      (property "Reference" "#PWR" (at 0 -3.81 0)
        (effects hide)
      )
      (property "Value" "VCC" (at 0 3.81 0)
      )
      (property "Footprint" "" (at 0 0 0)
        (effects hide)
      )
      (property "Datasheet" "" (at 0 0 0)
        (effects hide)
      )
      (property "ki_keywords" "global power" (at 0 0 0)
        (effects hide)
      )
      (property "ki_description" "Power symbol creates a global label with name \\"VCC\\"" (at 0 0 0)
        (effects hide)
      )
      (symbol "VCC_0_1"
        (polyline
          (pts
            (xy -0.762 1.27)
            (xy 0 2.54)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0 0)
            (xy 0 2.54)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
        (polyline
          (pts
            (xy 0 2.54)
            (xy 0.762 1.27)
          )
          (stroke (width 0) (type default))
          (fill (type none))
        )
      )
      (symbol "VCC_1_1"
        (pin power_in line (at 0 0 90) (length 0) hide
          (name "VCC")
          (number "1")
        )
      )
    )      
EOF
print "    $_->{'data'}\n" foreach (values %symb);
print  <<"EOF";
  )
EOF
#["WIRE","e743",[[195,740,220,740],[220,740,275,740]],"st9",0]
#["BUS","e31291",[[-485,420,-395,420],[-395,420,-395,465],[-395,465,-200,465],[-200,465,-200,560],[-200,560,-325,560]],"st9",0]
my %junc;
foreach (grep {$_->[0] eq 'WIRE' || $_->[0] eq 'BUS'} @$sch) {
  my $type=$_->[0] eq 'BUS' && 'bus' || 'wire';
  foreach (@{$_->[2]}) {
    my $xy1="${\($x_off+$_->[0]*0.254)} ${\($y_off-$_->[1]*0.254)}";
    my $xy2="${\($x_off+$_->[2]*0.254)} ${\($y_off-$_->[3]*0.254)}";
    $junc{$xy1}=$junc{$xy1}+1;
    $junc{$xy2}=$junc{$xy1}+1;
    print <<"EOF";
  ($type (pts (xy $xy1) (xy $xy2))
    (stroke (width 0) (type default))
  )
EOF
  }
}
foreach (keys %junc) {
  next unless $junc{$_}>1;
  print <<"EOF";
  (junction (at $_) (diameter 0) (color 0 0 0 0)
  )
EOF
}  
#["ATTR","e11193","e1322e24","NO_CONNECT","yes",0,0,545,440,0,"st2",0]
foreach (grep {$_->[0] eq 'ATTR' && $_->[3] eq 'NO_CONNECT'} @$sch) {
  print <<"EOF";
  (no_connect (at ${\($x_off+$_->[7]*0.254)} ${\($y_off-$_->[8]*0.254)}))
EOF
}
#["ATTR","e1800","e1628","NET","AP",0,1,125,440,0,"st2",0]
#["ATTR","e6225","e3677","NET","ALARM",0,1,1025,430,90,"st2",0]
foreach (grep {$_->[0] eq 'ATTR' && $_->[3] eq 'NET'} @$sch) {
  print <<"EOF" unless ($_->[4] eq 'GND' || $_->[4] eq 'AGND' || $_->[4] eq 'PGND' || $_->[4] eq 'VCC' || $_->[4] eq '+5V');
  (label "$_->[4]" (at ${\($x_off+$_->[7]*0.254)} ${\($y_off-$_->[8]*0.254)} $_->[9]) (fields_autoplaced)
    (effects $fonts{$_->[10]})
  )
EOF
}
#["RECT","e3",-60,-55,60,55,0,0,0,"st1",0]
foreach (grep {$_->[0] eq 'RECT'} @$sch) {
  print <<"EOF";
  (rectangle (start ${\($x_off+$_->[2]*0.254)} ${\($y_off-$_->[3]*0.254)}) (end ${\($x_off+$_->[4]*0.254)} ${\($y_off-$_->[5]*0.254)})
    $linestyles{$_->[9]}
  )
EOF
}
#["ARC","e14",4.44,-6.9,1.66049,0.08325,4.53,7.03,"st1",0]
foreach (grep {$_->[0] eq 'ARC'} @$sch) {
  eval {  # will fail if 3 points is in a line
    # can't believe that kiCAD does not support arcs with angles >180 degree, so hard to fix it
    my ($x1,$y1,$x2,$y2,$x3,$y3)=($x_off+$_->[2]*0.254,$y_off-$_->[3]*0.254,$x_off+$_->[4]*0.254,$y_off-$_->[5]*0.254,$x_off+$_->[6]*0.254,$y_off-$_->[7]*0.254);
    my ($x21,$x32,$x13,$y21,$y32,$y13)=($x2-$x1,$x3-$x2,$x1-$x3,$y2-$y1,$y3-$y2,$y1-$y3);
    my ($a,$b)=($x21*$y32-$y21*$x32, $x21*$y13-$y21*$x13);  # 0 means 3 points is in a line
    my ($c,$d)=($x1*$x1+$y1*$y1-$x2*$x2-$y2*$y2, $x1*$x1+$y1*$y1-$x3*$x3-$y3*$y3);
    my ($x0,$y0)=(-($y13*$c+$y21*$d)/$b/2, ($x21*$d+$x13*$c)/$b/2);
    my ($s1,$s3,$pi2)=(atan2($y1-$y0,$x1-$x0), atan2($y3-$y0,$x3-$x0), 4*atan2(1,0));
    my $ang=$a<0?($s3-$s1):($s1-$s3); $ang+=$pi2 if ($ang<0); #CCW running angle
    if ($ang>3.14) { # have to split it
      my $r=sqrt(($x1-$x0)*($x1-$x0)+($y1-$y0)*($y1-$y0));
      my ($x4,$y4)=($x0+$r*cos($s1+$ang/($a>0?2:-2)), $y0+$r*sin($s1+$ang/($a>0?2:-2)));
      my ($x5,$y5)=($x0+$r*cos($s1+$ang/($a>0?4:-4)), $y0+$r*sin($s1+$ang/($a>0?4:-4)));
      my ($x6,$y6)=($x0+$r*cos($s3-$ang/($a>0?4:-4)), $y0+$r*sin($s3-$ang/($a>0?4:-4)));
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
foreach (grep {$_->[0] eq 'POLY'} @$sch) {
  print <<"EOF";
  (polyline
    (pts
EOF
  my $pts=$_->[2];
  for (my $i=0; $i<$#$pts; $i+=2) {
  print <<"EOF";
      (xy ${\($x_off+$pts->[$i]*0.254)} ${\($y_off-$pts->[$i+1]*0.254)})
EOF
  }
  print <<"EOF";
    )
    $linestyles{$_->[4]}
  )
EOF
} 
#["BEZIER","e211",[-140,-20,-120,0,-90,0,-80,-10],"st1",0], not supported, just take a pose
foreach (grep {$_->[0] eq 'BEZIER'} @$sch) {
  print <<"EOF";
  (polyline
    (pts
EOF
  my $pts=$_->[2];
   for (my $i=0; $i<$#$pts; $i+=2) {
  print <<"EOF";
      (xy ${\($x_off+$pts->[$i]*0.254)} ${\($y_off-$pts->[$i+1]*0.254)})
EOF
  }
  print <<"EOF";
    )
    $linestyles{$_->[3]}
  )
EOF
} 
#["CIRCLE","e4",-55,50,1.5,"st1",0]
foreach (grep {$_->[0] eq 'CIRCLE'} @$sch) {
  print  <<"EOF";
  (circle (center ${\($x_off+$_->[2]*0.254)} ${\($y_off-$_->[3]*0.254)}) (radius ${\($_->[4]*0.254)})
    $linestyles{$_->[5]}
  ) 
EOF
} 
#["ELLIPSE","e206",-100,20,10,20,0,"st1",0], not supported, just take a pose
 foreach (grep {$_->[0] eq 'ELLIPSE'} @$sch) {
  print  <<"EOF";
  (circle (center ${\($x_off+$_->[2]*0.254)} ${\($y_off-$_->[3]*0.254)}) (radius ${\(($_->[4]+$_->[5])*0.127)})
    $linestyles{$_->[7]}
  ) 
EOF
} 
#["TEXT","e313",908,160,0,"yyy","st4",0]
foreach (grep {$_->[0] eq 'TEXT'} @$sch) {
  print  <<"EOF";
  (text "${\($_->[5]=~s/\n/\\n/gr)}" (at ${\($x_off+$_->[2]*0.254)} ${\($y_off-$_->[3]*0.254-$adj*2)} ${\($_->[4])})
    (effects $fonts{$_->[6]})
  )
EOF
} 
#["OBJ","e11178","",2352,1003,1665,568,270,0,"blob:af5d728faf1f71361bafcbb900560a871df62d84d9f2d7a9bd0ac12d20fca004",0]
foreach (grep {$_->[0] eq 'OBJ'} @$sch) {
  print STDERR "Load file '$dir".($_->[9]=~s/^\s*blob:\s*//r).".ersc'\n";
  next unless open F, "<$dir".($_->[9]=~s/^\s*blob:\s*//r).'.ersc';
  my $obj=from_json('['.join(',', <F>).']');
  close F;
  my $data=(map {$_->[3]=~s/^data\s*:.*;\s*base64\s*,\s*//ir} grep {$_->[0] eq 'BLOB'} @$obj)[0];
  print  <<"EOF" if ($data);
  (image (at ${\($x_off+($_->[3]+$_->[5]/2)*0.254)} ${\($y_off-($_->[4]-$_->[6]/2)*0.254)}) (scale 1)
      (data
        $data
      )
  )
EOF
} 
#done
print <<"EOF";
)
EOF
close STDOUT;
print STDERR "Done with '$ofname'\n" unless $ofname eq '-';