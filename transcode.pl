#!/usr/bin/perl

# Depends on ffmpeg, tested in macOS 10.12, ffmpeg 3.2.

use strict;
use warnings;

# Pre-defined resolutions
my $versions = [ '320', '640','1280', '1920', '2560' ];

sub create_multiple_bitrate_versions {
	my ($filename) = @_;

	for my $_version (@{$versions}){
		my $r = `ffmpeg -i $filename -vf scale=$_version:-1:force_original_aspect_ratio=decrease $_version/$filename -y`;
	}
}

sub create_multiple_segments {
	my ($filename) = @_;

	for my $_version (@{$versions}){
		my $r = `cd $_version; mp4box -dash 1000 -frag 1000 -rap -segment-name segment_ $filename; rm $filename; cd ..`;
	}
}

sub merge_manifests {
	print STDERR "NOT IMPLEMENTED\n";
}

my ($filename) = @ARGV;

unless( -e $filename ){
	print STDERR "Invalid file '$filename'\n";

	exit -1;
}

# create folders for the configured resolutions
`mkdir $_` for @{$versions};

# craate the multiple video bitrates
create_multiple_bitrate_versions($filename);

# split the videos in multiple segments
create_multiple_segments($filename);

merge_manifests();

1;