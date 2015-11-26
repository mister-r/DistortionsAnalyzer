# DistortionsAnalyzer
THD measurement and drawing Perl script for Linux.
I made this script to easily perform measurements while sound interface card attached to Linux headless ARM board. It works from console, access card via alsa, requires alsa-utils, sox and gnuplot (to draw spectrums into gif files).
Also it has feature - unlike most other similar software it outputs not only levels but also phases of first 3 harmonics, making possible to see different distortions kinds that are impossible to distinguish using power spectrum representation only. And difference between them really hearable - mostly due to coupling with non-linearity of acoustics.
- It can write results on stdout, text (raw) file or gif image with spectrum representation. Image also contains small glyphs that schematically represent how each particular distortion product affects sinusoidal signal.
- Two THD weighting algorithms implemented - normal THD and THD':
  - THD = 100 * sqrt(sum(Uk*Uk)) / U1 [k=2..products_count+1]  - this is commonly known THD weighting, nothing special
  - THD' = 100 * sqrt(sum(Uk*Uk*k*k/4)) / U1 [k=2..products_count+1]  - this is THD weighting used by BBC engeneers in 1950s, it addresses effect of greater audibility of higher order harmonics products.
- Can run in manually controlled or batch mode:
 - Manually controlled mode first allows user to adjust level and then performs distortions analyzis with iteractively entered frequencies and 'labels' that used to mark graphics and raw file records.
 - Batch mode executes distortion analyzis tests on frequencies/labels gived from command line. It doesn't require user input so can me used in automated environment.
- Wide customization options (see command line help)


Preparing: Install Perl if you don;t have it, run cpan and one by one execute following commands in cpan console to install required Perl packages:
install Audio::Wav
install Math::FFT
install Math::Trig
install Math::Round qw(:all)

Install gnuplot if you don't have it (if you want to get graphical spectrums images).
For command line options help type: ./DistortionsAnalyzer.pl -h

Usage:
Prepare your sound card and connect equipment to be tested to it in loopback mode.
Use aplay -l to find out your sound card identifier. Execute DistortionAnalyzer.pl script with at least following options that corresponds to you sound card identity:
./DistortionAnalyzer.pl -i hw:CARD,DEVICE -o hw:CARD,DEVICE
For example:
root@olinuxino:~# aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: sunxicodec [sunxi-CODEC], device 0: M1 PCM [sunxi PCM]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: USB [E-MU 0404 | USB], device 0: USB Audio [USB Audio]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
card 1: USB [E-MU 0404 | USB], device 1: USB Audio [USB Audio #1]
  Subdevices: 1/1
  Subdevice #0: subdevice #0

Mine EMU interface card number is 1 and device to be used 0, so minimal command line for this case is:
./DistortionsAnalyzer.pl -i hw:1,0 -o hw:1,0

After that - follow instructions (mostly press <ENTER> when asked for this).

Support urls:
 - English: http://www.diyaudio.com/forums/software-tools/282766-yet-another-thd-measurement-drawing-tool-but-linux-written-perl.html
 - Russian: http://forum.vegalab.ru/showthread.php?t=72818&p=2134404


Changelog:
v 1.5
 [ADDED] THD and THD' calculation
 [ADDED] Added batch mode (-b option)
 [ADDED] Added --g-logbase option
 [CHANGED] --g-fix option renamed to --g-range

v 1.4
 [ADDED] Schemtic distortion 'look' glyphs
 [ADDED] --g-fix option
 [CHABGED] Correct phases to zero main frequency phase
