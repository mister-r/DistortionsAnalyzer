#!/usr/bin/perl
#use Data::Dumper;
use Getopt::Std;
use Audio::Wav;
use Math::FFT;
use Math::Trig;
use Math::Round qw(:all);
use POSIX ":sys_wait_h";
use warnings;
use strict;
#use vars qw( $opt_i $opt_o $opt_r $opt_s $opt_t );

my $myver = "v1.4";
my $gnuplot = "gnuplot"; 
my $sox = "sox"; 
my $tmp_root = "/var/tmp";
my $tmp_wavplay = "$tmp_root/fft_play.wav";
my $tmp_wavrec = "$tmp_root/fft_rec.wav";
my $tmp_std = "$tmp_root/fft_std.txt";

my $dev_play = "hw:1,0";
my $dev_record = "hw:1,0";
my $sample_rate = "48000";
my $test_frequency = "1000";
my $analyze_channel = 1;
my $distorions_rec_time = 10;
my $raw_file = "";#fft_raw.txt";
my $graph_file = "";
my $faster = 0;
my $description = "Tested on " . localtime();
my $label = "";
my $graph_log_base = 10;
my $graph_size;# = "1920, 1080";
my $graph_fix;
my $playback_level = "0";

my $stop_it_all = 0;
my $raw_description_written = 0;

$SIG{INT} = sub { 
 $stop_it_all = 1;
# print "Got SIGINT $!\n" ;
};
$SIG{TERM} = sub { 
 $stop_it_all = 2;
# print "Got SIGTERM $!\n" ;
};

$graph_size = get_extended_option("g-size");
$graph_fix = get_extended_option("g-fix");

my %options=();
getopts('fhi:o:r:s:t:g:G:d:c:l:', \%options);

HELP_MESSAGE() if defined $options{h};

$analyze_channel = $options{c} if defined $options{c};
$faster = 1 if defined $options{f};
$dev_record = $options{i} if defined $options{i};
$dev_play = $options{o} if defined $options{o};
$sample_rate = $options{s} if defined $options{s};
$distorions_rec_time = $options{t} if defined $options{t};
$description = $options{d} if defined $options{d};

if (defined $options{g})
{
  $graph_file = $options{g};
  if ($graph_size eq "")
  {
    if ($sample_rate <= 48000) { $graph_size = "1920, 1080"; }
    elsif ($sample_rate <= 96000) { $graph_size = "3840, 1080"; }
    else  { $graph_size = "7680, 1080"; }
  }
  $graph_fix = -$graph_fix if $graph_fix ne "" && $graph_fix > 0;
}

if (defined $options{l})
{
  $playback_level = $options{l};
  if ($playback_level > 0)
  {
    $playback_level = -$playback_level;
    print STDERR "Positive playback level inverted to $playback_level db\n";
  }
}

if (defined $options{r})
{
  $raw_file = $options{r};
  unlink ($raw_file);
#  print "Raw data will be written to $raw_file\n";
}

print "Using $dev_play for playback, $dev_record for recording, $sample_rate samples per second\n";
print "Press <ENTER> to adjust levels or <Ctrl+C>, <ENTER> to exit\n";

getc(STDIN);
die "Cancelled" if $stop_it_all != 0;

$| = 1;

tmp_cleanup();

system ("reset");
print "\n---------------------------\n";
print "INPUT LEVEL ADJUSTEMENT\n";
print "Now script periodically outputs 1KHz via playback device and analyzes whats coming from recording device, calculating estimated level.";
print "Please use physical regulators to adjust level between -2..-0.5 db and press <ENTER> to continue with distortion analyzis.\n";
print "If you want to cancel everything and exit - press <Ctrl+C> and then <ENTER>\n";
print "\n---------------------------\n";

my $estimator_pid = fork();
if ($estimator_pid==0)
{
  while ($stop_it_all == 0)
  {
    play_and_record(\&estimate_file_level, 1, 0);
  }
  exit(0);
}
getc(STDIN);
print "Got <ENTER> keypress, wait a moment please...\n";
kill ('TERM', $estimator_pid);
waitpid_verbose($estimator_pid);

while ($stop_it_all == 0)
{
  system("reset");
  print "\n---------------------------\n";
  print "DISTORTIONS ANALYZIS\n";

  $test_frequency = ask_value("Specify base frequency, Hz", $test_frequency);
  $test_frequency = $test_frequency + 0;  

  if ($graph_file ne "" || $raw_file ne "")
  {
    $label = ask_value("Specify one word label for this test", $label);
    $label=~ s/[^\w]//g;
  }

  print "Base frequency set to $test_frequency Hz\n";
  play_and_record(\&analyze_file_distortions,  $distorions_rec_time, 1);
  print "Press <ENTER> to re-start distorions test or <Ctrl+C>, <ENTER> to exit\n";
  getc(STDIN);
}

tmp_cleanup();

sub HELP_MESSAGE
{
  my $myname = $0;
  $myname =~ s|(.*/)*||;
  print "Stupid and slow Distortions Analyzer $myver by misterzu (c)2015\n";
  print "Requires sox and alsa-utils (aplay, arecord).\n";
#  print "Usage: $myname [playback_device [recording_device [sample_rate [raw_file]]]].\n";
  print "Usage: $myname [-o playback_device] [-i recording_device] [-s sample_rate] [-c channel] [-l playback_level] [-t time] [-r raw_file] [-g graph_file [--g-size=\"width, height\"] [--g-fix=level]] [-d description] [-f] [-h]\n";
  print "Defaults: $myname -o $dev_play -i $dev_record -s $sample_rate -c $analyze_channel -t $distorions_rec_time -d $description\n";
  print "Clarifications:\n";
  print "\t-f - make calculations bit faster by the cost of minor precision loss\n";
  print "\t-h - show this help screen\n";
  print "\t-l option's argument is a negative level in db's or zero (default)\n";
  print "\t-g option requires gnuplot to be installed. Graph file name used with it should not include extension: frequency suffix + .gif extension will be added automatically.\n";
  print "\t--g-size option allows specifying graphics image size in pixels.\n";
  print "\t--g-fix allows to set fixed signal level range on graphics, value must be specified in db.\n";

  exit(1);
}

sub tmp_cleanup
{
  unlink($tmp_wavplay);
  unlink($tmp_wavrec);
  unlink($tmp_std);
}

sub ask_value
{
  my $prompt = shift;
  my $default = shift;
  print "$prompt ($default):";

  my $v = <STDIN>;
  $v =~ s/^\s+|\s+$//g ;
  $v = $default if $v eq "";
  return $v;
}

sub play_and_record
{
  my $analyze_routine = shift;
  my $rec_time = shift;
  my $verbose = shift;
  my $play_time = $rec_time + 1;

  my $gencmd = "$sox -b 24 -r $sample_rate -c 2 -n $tmp_wavplay synth $play_time sine $test_frequency";
  $gencmd .= " gain $playback_level" if $playback_level ne "0";
  $gencmd .= " >$tmp_std 2>&1";
  my $playcmd = "aplay -D $dev_play $tmp_wavplay";
  my $reccmd =  "arecord -D $dev_record -c 2 -r $sample_rate -fS24_3LE -B $play_time"."000000 -d $rec_time $tmp_wavrec";

#  $ENV{AUDIODEV}=$dev_record;
#  my $reccmd = "sox -t alsa $dev_record --buffer 4194304 -r $sample_rate -b 32 $tmp_wavrec trim 0.5 $rec_time";
#    system("play -n -t alsa --buffer 4194304 -r $sample_rate -b 32 synth $play_time sine $test_frequency >>play.out 2>>play.err");

  $playcmd .=  ">/dev/null 2>&1" if $verbose==0;
  $reccmd .= " >/dev/null 2>&1" if $verbose==0;

  print("Preparing $rec_time seconds of playback data");
  print(" (you may now take a cup of coffee)") if $play_time > 10;
  print("...\n");
  system($gencmd);

  print("Playing and recording...\n");
  
  my $child = fork();
  if ($child==0)
  {
     system($playcmd);
     exit(0);
  }

  select(undef, undef, undef, 0.5); #0.5 seconds delay
  unlink "$tmp_wavrec";
  system($reccmd);
  print "Analyzing... "; 
  $analyze_routine->(($tmp_wavrec));
  waitpid_verbose($child);
}

sub estimate_file_level
{
  my $file = shift;
  my $wav = new Audio::Wav;
  my $read = $wav -> read($file);

  my $info = $read->details();
  my $bps = $$info{bits_sample};
  die "No channel $analyze_channel in file" if $$info{channels} < $analyze_channel;

  my $max = 0;
  while(my @sample = ($read->read())) {
     $max = abs($sample[$analyze_channel - 1]) if $max < abs($sample[$analyze_channel - 1]);
  }

  my $lvl = get_level($bps, $max);

  print "Current level=", nearest(0.01, 2.0 * $lvl), " db";
  if ($lvl < -2)  { print " (LOW)\n"; }
  elsif ($lvl < -1)  { print " (GOOD)\n"; }
  elsif ($lvl < -0.5)  { print " (VERY GOOD)\n"; }
  elsif ($lvl < -0.1)  { print " (TOO HIGH)\n"; }
  else { print " (CLIPPING)\n"; }
}

sub get_level
{
  my $bps = shift;
  my $value = shift;
  return ratio_db($value, 0x7fff) if $bps==16;
  return ratio_db($value, 0x7fffff) if $bps==24;
  return ratio_db($value, 0x7fffffff) if $bps==32;
  die "Unsupported bits per sample $bps";
}

sub analyze_file_distortions
{
  my $file = shift;
#  my $raw_output_file = shift;
#  my $filtered_output_file = shift;
  print "Started distortions analyzis... ";

  my $wav = new Audio::Wav;
  my $read = $wav -> read($file);
  my $base = $file;
  $base =~ s/\.wav$//;


  my $info = $read->details();
  my $sample_freq = $$info{sample_rate}; # Sample frequency (Hz)
  my $time = $$info{length};      # Length of wav file in seconds
  my $bps = $$info{bits_sample};

  die "No channel $analyze_channel in file" if $$info{channels} < $analyze_channel;

  my ($normk, $cliplvl);
  if ($bps == 16)
  {
    $normk = 2147483647.0 / 32767.0; # 0x7fffffff / 0x7fff
    $cliplvl = 0x7fff;
    $bps = 32;
  }
  elsif ($bps == 24)
  {
    $normk = 2147483647.0 / 8388607.0; # 0x7fffffff / 0x7fffff
    $cliplvl = 0x7fffff;
    $bps = 32;
  }
  else
  {
    die "Unsupported BPS=$bps" if $bps != 32;
    $normk = 1.0;
    $cliplvl = 0x7fffffff;
  }

  print "Reading data... ";

  my ($samples_read, $samples_clipped, $max_abs_sample) = (0, 0, 0);
  my @data = ();

  while(my @datum = ($read->read())) {
    my $sample = $datum[$analyze_channel - 1];
    push(@data, $sample );
    $sample = abs($sample);
    $max_abs_sample = $sample if  $max_abs_sample < $sample;
    ++$samples_clipped if $sample >= $cliplvl;
    ++$samples_read;
  }
  my $att_level = 2.0 * ratio_db($cliplvl, $max_abs_sample);

  print "Loaded $samples_read samples: $time seconds of $sample_freq samples/second.\n";
  print STDERR "$samples_clipped SAMPLES ARE CLIPPED\n" if $samples_clipped != 0; 

  my ($prev_peakphase_abs, $zp_found) = (0, 0);
  my ($peakabs, $peakphase, $peakfreq, $coeff, $fft);
  print "Looking up zero-phase base sample..";
  my $offset_limit = 2 * ($sample_freq / $test_frequency); #allow passsing couple of periods..

  for (my $offset= 0;; ) 
  {
    my @data_spliced = @data;
    my $length_spliced = find_lower_power_of_two($samples_read - $offset);

    if ($length_spliced > 65536 && $zp_found == 0 && $faster != 0 )
    {
      my $delta = round(($length_spliced - 65536) / 2);
      $length_spliced = 65536;
      splice @data_spliced, 0, $offset + $delta;
      splice @data_spliced, $length_spliced;
    }
    else
    {
      die "Too few samples" if $length_spliced < 65536;
      splice @data_spliced, 0, $offset if $offset > 0;
      splice @data_spliced, $length_spliced if $length_spliced > 0;
    }

    for (my $i = 0; $i < $length_spliced; ++$i)
    {
     $data_spliced[$i] *= $normk * sin( (pi * $i) / ($length_spliced) );
    }

    $fft = new Math::FFT(\@data_spliced);
    $coeff = $fft->rdft();
    ($peakabs, $peakphase, $peakfreq) = lookup_fft_peak($coeff, $sample_freq, $test_frequency);
    my $peakphase_abs = abs($peakphase);
    last if $zp_found!=0; #$peakphase_abs == 0 || $prev_peakphase_abs < 0;

#    my $clvl = get_level($bps, abs(@data_spliced[$length_spliced/2]));
#    print "Analyzing $length_spliced samples. Phase " . round($peakphase) . ". Center level ".round($clvl) . " db " . ((@data_spliced[$length_spliced/2]>=0)?"above" : "below") . " zero.\n";


    if ($peakphase_abs == 0)
    {
      last if $faster == 0;
      $zp_found = 1;
    }
    elsif ($offset > 0 && $prev_peakphase_abs < $peakphase_abs && $peakphase_abs < 80)
    {
      --$offset;
      $zp_found = 2;
    }
    else
    {
      ++$offset;
      if ($offset > $offset_limit)
      {
        print STDERR "Base sample lookup failed";
        $zp_found = 3;
      }
    }
    $prev_peakphase_abs = $peakphase_abs;
    if ( $zp_found!=0 ) { print "!"; }
    elsif ($offset < ($offset_limit/4)) { print "."; }
    elsif ($offset < ((2 * $offset_limit)/4)) { print ":"; }
    elsif ($offset < ((3 * $offset_limit)/4)) { print "="; }
    else { print "#"; }
  }

  my ($base_peakabs, $base_peakphase) = ($peakabs, $peakphase);
  print "\nChannel $analyze_channel. SPL attenuated by " . nearest(0.1, $att_level) . " db.\n";
  print "Normalized for base frequency ", round($peakfreq), " Hz\n";
  print "Hz \tDb \tDegrees\n";
  for (my $harm_index = 2; $harm_index <= 5; ++$harm_index)
  {
    last if $test_frequency * $harm_index > $sample_freq / 2;
    ($peakabs, $peakphase, $peakfreq) = lookup_fft_peak($coeff, $sample_freq, $test_frequency * $harm_index);
    my $db = round(2 * ratio_db($peakabs, $base_peakabs));
    print round($peakfreq)," \t", round($db), " \t", round($peakphase - $harm_index * $base_peakphase), "\n";
  }

  write_raw_data($coeff, $sample_freq, $raw_file, $att_level) if $raw_file ne "";
  if ($graph_file ne "")
  {
    my $graph_file_full = $graph_file . "_$test_frequency";
    $graph_file_full .= "_$label" if $label ne "";
    $graph_file_full .= ".gif";
    write_graph($coeff, $sample_freq, $graph_file_full, $att_level);
  }
}

sub write_raw_data
{
  my $coeff = shift;
  my $sample_freq = shift;
  my $file = shift;
  my $att_level = shift;

  if (open(out_raw, ">>$file"))
  {
    print "Writing raw data into $raw_file... ";
    if ($raw_description_written==0 && $description ne "") 
    {
      $raw_description_written = 1;
      print out_raw "#", $description, "\n";
      print out_raw "#---------------------------------------------\n";
    }

    print out_raw "#Channel $analyze_channel. SPL attenuated by " . nearest(0.1, $att_level) . " db.\n";
    print out_raw "#", $label, "\n" if $label ne "";
    print out_raw "#Base frequency $test_frequency Hz\n";
    my $unit = $sample_freq / ($#$coeff + 1);
    for (my $freq = 1; $freq<($sample_freq/2); $freq+= $unit)
    {
      my ($abs, $phase) = get_fft_point($coeff, $sample_freq, $freq);
      print out_raw round($freq), " \t", round($abs), " \t", round($phase), "\n";
    }
    print out_raw "#---------------------------------------------\n";
    close(out_raw);
  } 
  else
  {
    print STDERR "Failed to create $file\n";
  }
  print "Done\n";
}

sub write_graph
{
  my $coeff = shift;
  my $sample_freq = shift;
  my $file = shift;
  my $att_level = shift;

  print "Writing graph file $file... ";

  my $peak_lookup_freq = $test_frequency; 
  my $max_abs = 0;
  my $unit = $sample_freq / ($#$coeff + 1);
  my $max_freq = round($sample_freq/2);

  my $file_dat = "$file\.dat";

  for (my $freq = 1; $freq<($sample_freq/2); $freq+= $unit)
  {
    my ($abs, $phase) = get_fft_point($coeff, $sample_freq, $freq);
    $max_abs = $abs if $max_abs < $abs;
  }

  my ($h1_peak_abs, $h1_peak_phase, $h1_peak_freq) = lookup_fft_peak_normalized($coeff, $sample_freq, $test_frequency, $max_abs); 
  my ($h2_peak_abs, $h2_peak_phase, $h2_peak_freq) = lookup_fft_peak_normalized($coeff, $sample_freq, 2 * $test_frequency, $max_abs); 
  my ($h3_peak_abs, $h3_peak_phase, $h3_peak_freq) = lookup_fft_peak_normalized($coeff, $sample_freq, 3 * $test_frequency, $max_abs); 
  my ($h4_peak_abs, $h4_peak_phase, $h4_peak_freq) = lookup_fft_peak_normalized($coeff, $sample_freq, 4 * $test_frequency, $max_abs); 
  $h2_peak_phase-= 2 * $h1_peak_phase;
  $h3_peak_phase-= 3 * $h1_peak_phase;
  $h4_peak_phase-= 4 * $h1_peak_phase;
  $h1_peak_phase = 0;

  my $title = "Channel $analyze_channel";
  $title .= " ($label)" if $label ne "";
  $title .= ". $description (generated by Distortions Analyzer $myver by misterzu)";

  my $xlabel = "Frequency, Hz (sample rate $sample_rate)";
  my $ylabel = "SPL, db (attenuated by " . nearest(0.1, $att_level) . " db";
  $ylabel .= ", playback level $playback_level db" if $playback_level ne "0";
  $ylabel .= ")";

  my $set_yrange = "";
  $set_yrange = "set yrange [$graph_fix:0]\n" if $graph_fix ne "";

  print "Executing $gnuplot... ";
  open(PLOT, "|$gnuplot") or die;
  print PLOT <<EOF;
set term gif size $graph_size
set output "$file"
set size 1, 1
set nokey
set style data lines

set title "$title\\n";
set bmargin 3
#set xlabel "$xlabel"
set ylabel "$ylabel"

$set_yrange
set xrange [10:$max_freq]
set logscale x $graph_log_base
set mxtics
set mytics
set grid xtics ytics mytics

set label 1 "$h2_peak_phase°" at first $h2_peak_freq, 5 center
set label 2 "$h3_peak_phase°" at first $h3_peak_freq, 5 center
set label 3 "$h4_peak_phase°" at first $h4_peak_freq, 5 center
set label 4 "$xlabel" at character 10, 1

set multiplot

plot "-" using 1:2 w lines axes x1y1 lt rgb "#0000FF"
EOF

  for (my $freq = 1; $freq<$max_freq; $freq+= $unit)
  {
    my ($abs, $phase) = get_fft_point($coeff, $sample_freq, $freq);
    print PLOT $freq, " \t", 2 * ratio_db($abs, $max_abs), "\t", $phase, "\n" if $abs > 0;
  }
  print PLOT "e\n";

  print PLOT <<EOF;
set yrange [-10:400]
unset grid
unset mxtics
unset mytics
unset xtics
unset ytics
unset xlabel
unset ylabel
unset label 1
unset label 2
unset label 3
unset label 4
unset title
unset border
unset logscale x
set xrange [0:10000]
set lmargin 8
set bmargin 0
EOF

  my $kofs = 9970 / (log_N($graph_log_base, $max_freq) - 1); 
  my $ofs = $kofs * (log_N($graph_log_base, $h2_peak_freq) - 1) - 150;
  write_plot_distortion_icon ($ofs, $h1_peak_phase, $h2_peak_phase, 2, 300);
  $ofs = $kofs * (log_N($graph_log_base, $h3_peak_freq) - 1) - 150;
  write_plot_distortion_icon ($ofs, $h1_peak_phase, $h3_peak_phase, 3, 300);
  $ofs = $kofs * (log_N($graph_log_base, $h4_peak_freq) - 1) - 150;
  write_plot_distortion_icon ($ofs, $h1_peak_phase, $h4_peak_phase, 4, 300);
  close(PLOT);
  print "Done\n";
}

sub write_plot_distortion_icon
{
  my $ofs = shift;
  my $phase1 = shift;
  my $phase2 = shift;
  my $order = shift;
  my $count = shift;

  my @mix = (0) x $count;
  add_harm_to_mix(\@mix, 10, $phase1, 1);
  add_harm_to_mix(\@mix, 1.5, $phase2, $order);
  normalize_mix(\@mix, 10);

  print PLOT "plot \"-\" using 1:2 w lines axes x1y1 lt rgb \"#FF00FF\"\n";
  for (my $i = 0; $i < $count; ++$i)
  {
    print PLOT ($ofs + $i) . " " . $mix[$i] . "\n"; 
  }
  print PLOT "e\n";
}

sub add_harm_to_mix
{
  my $target = shift;
  my $abs = shift;
  my $phase = shift;
  my $order = shift;

  my $samples = $#$target + 1;
  my $delta = 2.0 * pi * $order / $samples;
#-round($samples / 4)

  for (my ($a, $i) = ($delta * $samples / 4 + pi / 2 + $phase * pi / 180, 0); $i < $samples; $a+= $delta, ++$i)
  {
      if ( $order == 1)
      {
        $target->[$i] = sin($a) * $abs;
      }
      else
      {
        $target->[$i]-= sin($a) * $abs;
      }
  }
}

sub normalize_mix
{
  my $target = shift;
  my $limit_abs = shift;

  my ($samples, $max_abs) = ($#$target + 1, 0);

  for (my $i = 0; $i < $samples; ++$i)
  {
    $max_abs = abs($target->[$i]) if $max_abs < abs($target->[$i]);
  }
  if ($max_abs > 0)
  {
    my $normk = $limit_abs / $max_abs;
    for (my $i = 0; $i < $samples; ++$i)
    {
      $target->[$i]*= $normk;
    }
  }
}

sub lookup_fft_peak_normalized
{
  my $coeff = shift;
  my $sample_freq = shift;
  my $lookup_freq = shift;
  my $reference_level = shift;

  my ($outabs, $outphase, $outfreq) = lookup_fft_peak($coeff, $sample_freq, $lookup_freq);
  $outabs = 2 * ratio_db($outabs, $reference_level) if $outabs;
  return (round($outabs), round($outphase), round($outfreq));
}

sub lookup_fft_peak
{
  my $coeff = shift;
  my $sample_freq = shift;
  my $lookup_freq = shift;

  my $lookup_freq_begin = ($lookup_freq > 100) ? $lookup_freq - 100 : 1;
  my $lookup_freq_end = $lookup_freq + 100;
  $lookup_freq_end = $sample_freq / 2 if $lookup_freq_end > ($sample_freq / 2);

  my $unit = $sample_freq / ($#$coeff + 1);

  my ($outabs, $outphase, $outfreq) = (0, 0, 0);

  for (my $freq = $lookup_freq_begin; $freq < $lookup_freq_end; $freq += $unit)
  {
    my ($abs, $phase) = get_fft_point($coeff, $sample_freq, $freq);
    if ($outabs <= $abs)
    {
      $outabs = $abs;
      $outphase = $phase;
      $outfreq = $freq;
    }
  }

  return ($outabs, $outphase, $outfreq);
}

sub get_fft_point
{
  my $coeff = shift;
  my $sample_freq = shift;
  my $lookup_freq = shift;

  my $unit = $sample_freq / ($#$coeff + 1);
  my $coeff_records = @$coeff / 2;

  my $ci = round($lookup_freq / $unit);
  my $phase = Math::Trig::atan2($coeff->[$ci * 2 + 1], $coeff->[$ci * 2]) * 180.0 / pi;
  my $abs = sqrt( $coeff->[$ci * 2]**2 + $coeff->[$ci * 2 + 1]**2 );
  return ($abs, $phase);
}

sub find_lower_power_of_two
{
  my $value = shift;
  my $out = 1;
  while (($out * 2) <= $value) { $out*= 2; }
  return $out;
}

sub ratio_db
{
  my $dividend = shift;
  my $divisor = shift;
  return 10.0 * log_10( $dividend / $divisor );
}


sub log_10
{
  my $v = shift;
  return log_N(10.0, $v);
}

sub log_N
{
  my $n = shift;
  my $v = shift;
  return log($v)/log($n);
}

sub waitpid_verbose
{
  my $pid = shift;
#  if (waitpid($pid, WNOHANG)>0)
  {
#    print "Waiting for process $pid exit...\n";
    waitpid($pid, 0);
  }
}

sub get_extended_option
{
  my $opt = shift;
  my $argc = $#ARGV + 1;

  for (my $i = 0; $i < $argc; ++$i)
  {
    if ($ARGV[$i]=~ /^--$opt=(.*)/ )
    {
      splice @ARGV, $i, 1;
      return unquote($1);
    }
  }

  return "";
}
