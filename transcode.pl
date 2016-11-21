#!/usr/bin/perl
# Depends on ffmpeg and mp4box. Tested in macOS 10.12, ffmpeg 3.2, mp4box GPAC version 0.6.1.
use strict;
use warnings;
use XML::Simple;

# Pre-defined resolutions
my $versions = [ '320', '640', '720', '1280', '1920', '2560' ];

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
	my ($filename) = @_;
	my $high_res = 0;
	my $fd;
	# cleanup extension
	$filename =~ s/(\w+)\..*$/$1/;
	$filename =~ s/\W+(\w+)\.*?/$1/;
	# choose the higher resolution
	for (@{$versions}){
		$high_res = int($_) if $_ > $high_res;
	}
	my $xml = new XML::Simple (KeyAttr => []);
	# open the base manifest file
	my $base_manifest = $xml->XMLin("$high_res/$filename"."_dash.mpd");
	# update the segments path
	for my $segment (@{$base_manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{SegmentURL}}){
		$segment->{media} = "$high_res/".$segment->{media};
	}
	$base_manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{Initialization}->{sourceURL} = "$high_res/".$base_manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{Initialization}->{sourceURL};
	# set id
	$base_manifest->{Period}->{AdaptationSet}->{Representation}->{id} = $high_res;
	# copy the higher representation reference
	my $high_representation = $base_manifest->{Period}->{AdaptationSet}->{Representation};
	#force representations to be a list
	$base_manifest->{Period}->{AdaptationSet}->{Representation} = [];
	# merge the rest
	for (@{$versions}){
		# skip if is the base one
		next if int($_) eq $high_res;
		# open the remaining manifest files to merge the representations with the base one
		my $manifest = XMLin("$_/$filename"."_dash.mpd");
		# set id
		$manifest->{Period}->{AdaptationSet}->{Representation}->{id} = $_;
		# set the proper BaseURL
		for my $segment (@{$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{SegmentURL}}){
			$segment->{media} = "$_/".$segment->{media};
		}
		$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{Initialization}->{sourceURL} = "$_/".$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentList}->{Initialization}->{sourceURL};
		push $base_manifest->{Period}->{AdaptationSet}->{Representation}, $manifest->{Period}->{AdaptationSet}->{Representation};
		my $res_filename = "$_/$filename"."_dash.mpd";
		`rm $res_filename`;
	}
	push $base_manifest->{Period}->{AdaptationSet}->{Representation}, $high_representation;
	delete $base_manifest->{ProgramInformation};
	my $high_res_filename = "$high_res/$filename"."_dash.mpd";
	`rm $high_res_filename`;
	open $fd, '>', "$filename"."_dash.mpd" or die "open($filename"."_dash.mpd): $!";
	$xml->XMLout($base_manifest, OutputFile => $fd, RootName => "MPD", XMLDecl => '<?xml version="1.0"?>' );
}

my ($filename) = @ARGV;

unless( -e $filename ){
	print STDERR "Invalid file '$filename'\n";
	exit -1;
}

# cleanup
`rm -rf $_` for @{$versions};
# create folders for the configured resolutions
`mkdir $_` for @{$versions};
# craate the multiple video bitrates
create_multiple_bitrate_versions($filename);
# split the videos in multiple segments
create_multiple_segments($filename);
# merge all the manifests in a single onez§
merge_manifests($filename);

1;
