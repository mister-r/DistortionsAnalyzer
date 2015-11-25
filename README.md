# DistortionsAnalyzer
THD measurement and drawing Perl script for Linux
I made this script to easily perform measurements while sound interface card attached to Linux headless ARM board. It works from console, access card via alsa, requires alsa-utils, sox and gnuplot (to draw spectrums into gif files). Also it requires several additional modules to be installed into Perl with cpan: Audio::Wav, Math::FFT, Math::Trig, Math::Round.
Also it has feature - unlike most other similar software it outputs not only levels but also phases of first 3 harmonics, making possible to see different distortions kinds that are impossible to distinguish using power spectrum representation only. And difference between them really hearable - mostly due to coupling with non-linearity of acoustics.

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

