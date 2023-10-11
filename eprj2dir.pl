use DBI;
use JSON;
die <<"EOF" if $#ARGV<0;
Usage: perl $0 <.eprj file name> <directory name, can be ignored for using the same name>
  It will extract all Schematics/PCBs/Symbols/Footprints/Devices/Resources from input file,
  and save them to a new directory.
EOF
die "Unable to find '$ARGV[0]'\n" unless -e $ARGV[0];
$dbh=DBI->connect("DBI:SQLite:dbname=$ARGV[0]", '', '', {PrintError=>0}) or  die "Unable to connect file '$ARGV[0]': ".DBI::errstr."\n";
$dir=$#ARGV>0 && $ARGV[1] || $ARGV[0]=~s/\.[^\.]*$//r;
die "Failed to make new directory '$dir', $!\n" unless mkdir($dir) && chdir($dir);
print STDERR "Directory '$dir' is created, which contains all output files\n";
# Schematics
$sth=$dbh->prepare("SELECT title,dataStr from documents where docType=1 and title is not null and title!=''") and $sth->execute()>=0 or  die "Failed to extract schematics data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	$row[0]=~tr/\*\|\"\?\/\\\&;\<\> /_/;
	$row[1]=~s/\r*(?=\n)//gm;;
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].esch";
	print F $row[1];
	close F; 
}
$sth->finish();
#PCBs
$sth=$dbh->prepare("SELECT title,dataStr from documents where docType=3 and title is not null and title!=''") and $sth->execute()>=0 or  die "Failed to extract PCB data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	$row[0]=~tr/\*\|\"\?\/\\\&;\<\> /_/;
	$row[1]=~s/\r*(?=\n)//gm;;
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].epcb";
	print F $row[1];
	close F; 
}
$sth->finish();
#Symbols
$sth=$dbh->prepare("SELECT uuid,dataStr from components where docType=2 and title is not null and title!=''") and $sth->execute()>=0 or  die "Failed to extract symbol data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	$row[1]=~s/\r*(?=\n)//gm;;
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].esym";
	print F $row[1];
	close F; 
}
$sth->finish();
# Footprints
$sth=$dbh->prepare("SELECT uuid,dataStr from components where docType=4 and title is not null and title!=''") and $sth->execute()>=0 or  die "Failed to extract footprint data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	$row[1]=~s/\r*(?=\n)//gm;;
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].efoo";
	print F $row[1];
	close F; 
}
# resources
$sth=$dbh->prepare("SELECT hash,dataStr from resources") and $sth->execute()>=0 or  die "Failed to extract resources data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].ersc";
	print F $row[1];
	close F; 
}
$sth->finish();
# Devices
my $dev={};
my $last_dev;
$sth=$dbh->prepare("SELECT device_uuid, key, value from attributes order by device_uuid") and $sth->execute()>=0 or  die "Failed to extract device data from file '$ARGV[0]': ".DBI::errstr."\n";
while(my @row = $sth->fetchrow_array()) {
	$dev->{$row[0]}={} unless exists $dev->{$row[0]};
	$dev->{$row[0]}->{$row[1]}=$row[2];
}
$sth->finish();
open F, ">devices.json";
print F to_json($dev,{'indent'=>1});
close F;

#all done
$dbh->disconnect();