# DistortionsAnalyzer
THD measurement and drawing Perl script for Linux
I made this script to easily perform measurements while sound interface card attached to Linux headless ARM board. It works from console, access card via alsa, requires alsa-utils, sox and gnuplot (to draw spectrums into gif files). Also it requires several additional modules to be installed into Perl with cpan: Audio::Wav, Math::FFT, Math::Trig, Math::Round.
Also it has feature - unlike most other similar software it outputs not only levels but also phases of first 3 harmonics, making possible to see different distortions kinds that are impossible to distinguish using power spectrum representation only. And difference between them really hearable - mostly due to coupling with non-linearity of acoustics.
For command line options help: DistortionsAnalyzer.pl -h
