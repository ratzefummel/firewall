#!/usr/bin/perl 

use Time::Local;
use POSIX;

# config-teil
$dumpfile = "/etc/fw/dump.log";
$logfile = "/etc/fw/traffic.log";
@accounts = qw(eth_0_in eth_0_out eth_1_in eth_1_out gw_in   gw_out   all_in all_out);

format STDOUT_TOP =

Report from @<<<<<<<<<<<<<<<<<<<
            $datum
            
    Rulename        |      Bytes | Packages | Bytes/Pkg
   -----------------------------------------------------
.

format STDOUT = 
    @<<<<<<<<<<<<<< | @>>>>>>>>> | @>>>>>>> | @>>>>>>>>
   $el, &format_num($inbytes{$el}), $inpkgs{$el}, $bytes_per_pkg{$el} 
.

#soll geloggt werden ?
if ( $ARGV[0] eq "-l" )
{
   # loggen
#   $logfile = $ARGV[1];
   
   # iptables-ausgabe erzeugen in dumpfile
   unlink($dumpfile);
   foreach $el (@accounts)
   {
      $bytes{$el} = 0;
      $pkgs{$el} = 0;
      system("iptables -nvx -L $el -Z $el >> $dumpfile 2> /dev/null");
   }

   # dumpfile einlesen
   open(DUMP, "< $dumpfile") or die "Could not open $dumpfile: $!\n";
   @inhalt = <DUMP>;
   close(DUMP);

   # bytes und pkgs aus dumpfile lesen/ablegen
   for ($j = 2, $i = 0; $j <= $#inhalt; $j += 4, $i++)
   {
      split(/ +/, $inhalt[$j]);
      $pkgs{$accounts[$i]} = $_[1];
      $bytes{$accounts[$i]} = $_[2];
   }

   #letzte Zeile einlesen
   open(LOG, "< $logfile") or die "Could not open logfile $logfile: $!\n";
   while ( <LOG> ) { 
      if ( $_ ) {
         $lastline = $_;
	 $pos = tell(LOG) - length($lastline);
      }
   }
   close(LOG);
   
   #extrahieren von Tag, Monat und Jahr aus letzter Zeile und jetzt
   @lastlog = split(/ +/, $lastline);
   ($log_day, $log_month, $log_year) = (localtime($lastlog[0]))[3,4,5];
   ($day, $month, $year) = (localtime(time))[3,4,5];

   # pruefen, ob die letzte zeile bereits einen eintrag fuer heute enthaelt 
   if ( ($log_day eq $day) && ($log_month eq $month) && ($log_year eq $year) )
   {
      for ($i = 1; $i <= $#lastlog; $i+=3)
      {
         $bytes{$lastlog[$i]} = $bytes{$lastlog[$i]} + $lastlog[$i+1];  
         $pkgs{$lastlog[$i]} = $pkgs{$lastlog[$i]} + $lastlog[$i+2];
      }
   }
   else {
      $pos = -s $logfile;
   }
   
   #zusammensetzen des neuen logeintrags
   $newlogentry = time;
   foreach $el (@accounts) {
      $newlogentry .= " $el $bytes{$el} $pkgs{$el}";
   }
   $newlogentry .= "\n";

   # schreiben ins logfile
   open(LOG, "+< $logfile") or die "Could not open logfile $logfile: $!\n";
   seek(LOG, $pos, SEEK_SET);
   print LOG time;
   foreach $el (@accounts) {
      print LOG " $el $bytes{$el} $pkgs{$el}";
   }
   print LOG "\n";
   close(LOG);

}
elsif ( $ARGV[0] eq "-r") 
{
   # create/view report, evtl. $ARGV[1] auf Gueltigkeit uebberpruefen
   if ( $ARGV[1] ) {
      $reportdate = $ARGV[1];
   }
  
   #eingabe zerlegen in tag, monat und jahr; daraus erzeugung des timestamps;
   #bestimmung des intervalls fuer logeintrag
   ( $report_dd, $report_mm, $report_yy ) = ( $reportdate =~ /(\d+)-(\d+)-(\d+)/ );
   $report_min = timelocal(0, 0, 0, $report_dd, $report_mm-1, $report_yy);
   $report_max = $report_min + 3600*24 - 1;

   #logfile oeffnen und suche nach erstem eintrag mit richtigem datum
   open(LOG, "< $logfile") or die "Could not open logfile $logfile: $!\n";
   while ( $line = <LOG> )
   {
      chomp $line;
      split(/ +/, $line);
      $datum = localtime($_[0]);
      if ( ($_[0] >= $report_min) && ($_[0] <= $report_max) ) 
      {

         #logeintrag zerlegen in namen, bytes und pkgs; berechnung von 
	 #Bytes/Pkg
         for ($i = 1; $i <= $#_; $i+=3)
         {
            $inbytes{$_[$i]} = $_[$i+1];  
            $inpkgs{$_[$i]} = $_[$i+2];
            if ( $inpkgs{$_[$i]} ne "0" ) {
               $bytes_per_pkg{$_[$i]} = sprintf("%.1f",  $_[$i+1] / $_[$i+2]); 
            }
            else {
               $bytes_per_pkg{$_[$i]} = 0;
            }
         }
  
         foreach $el (@accounts) {
            write;
         }

         #eintrag wurde ausgegeben, suche beenden
         last;
      }
   }
   close(LOG);
   
}
else
{ 
   die "Usage: $0 options
      -r date        show report (date format: dd-mm-yy)
      -l logfile     logs new entry\n";
}

sub format_num
{
   local $number = $_[0];

   if ( $number > 0 )
   {   
      if ( $number > 1048576) {
         $number = sprintf("%.2fM", $number / 1048576);
      }
      elsif ( $number > 1024 ) {
         $number = sprintf("%.2fk", $number / 1024);
      }
   }
   else {
      $number = 0;
   }
   return $number;
}