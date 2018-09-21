#!/usr/bin/perl
# Depends on ffmpeg and mp4box. Tested in macOS 10.12, ffmpeg 3.2, mp4box GPAC version 0.6.1.
use strict;
use warnings;
use XML::Simple;

my $config = {
    keyint  => '59',
    framerate => '30000/1001',
    profile  => 'live',
    chunk => '2000',
};

# Pre-defined resolutions
my $versions = [ '320', '640', '720', '1280', '1920', '2560' ];

sub create_multiple_bitrate_versions {
	my ($filename) = @_;
	my $lastVersion = '';
	for my $_version (@{$versions}){
		my $r = `ffmpeg -i $filename -vf scale=$_version:-2 -x264opts 'keyint=$config->{keyint}:min-keyint=$config->{keyint}:no-scenecut' -strict -2 -r $config->{framerate} $_version/$filename -y`;
		$lastVersion = $_version;
	}
	my $r = `cp $lastVersion/$filename audio/$filename`;
}

sub create_multiple_segments {
	my ($filename) = @_;
	for my $_version (@{$versions}){
		my $r = `cd $_version; MP4Box -dash $config->{chunk} -frag $config->{chunk} -rap -frag-rap -profile $config->{profile} $filename#video; rm $filename; cd ..`;
	}
	my $r = `cd audio; MP4Box -dash $config->{chunk} -frag $config->{chunk} -rap -frag-rap -profile $config->{profile} $filename#audio; rm $filename; cd ..`;
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
	$base_manifest->{Period}->{AdaptationSet} = [$base_manifest->{Period}->{AdaptationSet}];
	$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}->{SegmentTemplate}->{media} = "$high_res/".$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}->{SegmentTemplate}->{media};
	$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}->{SegmentTemplate}->{initialization} = "$high_res/".$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}->{SegmentTemplate}->{initialization};
	# set id
	$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}->{id} = $high_res;
	# copy the higher representation reference
	my $high_representation = $base_manifest->{Period}->{AdaptationSet}->[0]->{Representation};
	#force representations to be a list
	$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation} = [];
	# merge the rest
	for (@{$versions}){
		# skip if is the base one
		next if int($_) eq $high_res;
		# open the remaining manifest files to merge the representations with the base one
		my $manifest = XMLin("$_/$filename"."_dash.mpd");
		# set id
		$manifest->{Period}->{AdaptationSet}->{Representation}->{id} = $_;
		$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{media} = "$_/".$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{media};
		$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{initialization} = "$_/".$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{initialization};
		push (@{$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}}, $manifest->{Period}->{AdaptationSet}->{Representation});
		my $res_filename = "$_/$filename"."_dash.mpd";
		`rm $res_filename`;
	}
	push (@{$base_manifest->{Period}->{AdaptationSet}->[0]->{Representation}}, $high_representation);

	# open the audio manifest file to merge the representations with the base one
	my $manifest = XMLin("audio/$filename"."_dash.mpd");
	# set id
	$manifest->{Period}->{AdaptationSet}->{Representation}->{id} = "audio";
	$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{media} = "audio/".$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{media};
	$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{initialization} = "audio/".$manifest->{Period}->{AdaptationSet}->{Representation}->{SegmentTemplate}->{initialization};
	push (@{$base_manifest->{Period}->{AdaptationSet}}, $manifest->{Period}->{AdaptationSet});
	my $res_filename = "audio/$filename"."_dash.mpd";
	`rm $res_filename`;

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
# create folders for the config->ured resolutions
`mkdir $_` for @{$versions};
# create folders for the audio
`mkdir audio`;
# craate the multiple video bitrates
create_multiple_bitrate_versions($filename);
# split the videos in multiple segments
create_multiple_segments($filename);
# merge all the manifests in a single onez§
merge_manifests($filename);

1;
