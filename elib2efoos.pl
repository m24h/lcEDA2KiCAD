use DBI;

die "Usage: perl $0 <.elib .eprj file name> \n\tIt will extract all footprints and save them to this directory.\n" if $#ARGV<0;
die "Unable to find '$ARGV[0]'\n" unless -e $ARGV[0];
$dbh=DBI->connect("DBI:SQLite:dbname=$ARGV[0]", '', '', {PrintError=>0}) or  die "Unable to connect file '$ARGV[0]': ".DBI::errstr."\n";
$sth=$dbh->prepare("SELECT title,dataStr from components where docType=4 and title is not null and title!=''") and $sth->execute()>=0 or  die "Failed to extract footprint data from file '$ARGV[0]': ".DBI::errstr."\n";

while(my @row = $sth->fetchrow_array()) {
	$row[0]=~tr/\*\|\"\?\/\\\&;\<\> /_/;
	$row[1]=~s/\r*(?=\n)//gm;;
	next unless $row[0] && $row[1];
	next unless open F, ">$row[0].efoo";
	print F $row[1];
	close F; 
}
$sth->finish();
$dbh->disconnect();