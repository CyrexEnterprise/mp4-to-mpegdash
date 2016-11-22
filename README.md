# mp4-to-mpegdash
Perl script to convert a MP4 video into MPEG-DASH

- Creates the multiple bitrate versions to a pre-defined set of resolutions ('320', '640', '720', '1280', '1920', '2560')
- Split the versions into segments of 1 second (by default)
- Handle the main MPEG-DASH manifest file.

# Dependencies

FFmpeg https://www.ffmpeg.org/
MP4Box https://gpac.wp.mines-telecom.fr/mp4box/

## Perl Dependencies

XML::Simple

# Usage
`$ perl transcode.pl $FILENAME`

# TODO
Update script to merge manifests.
