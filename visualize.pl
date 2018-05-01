#!/usr/bin/perl
use strict;
use Getopt::Long;
use GD;

#################

my $width=640;
my $height;

#################

my $fps=30;
my $vcodec = "libx264";
my $ext = "mp4";

#################

my @files;
my $audio;
my $debug = 0;
my $amplify = 0;
my $output = "output.$ext";

GetOptions (
	'input=s{1,}' => \@files,
	'audio=s' => \$audio,
	'width=i' => \$width,
	'height=i' => \$height,
	'output=s' => \$output,
	'fps=i' => \$fps,
	'amplify' => \$amplify,
	'debug' => \$debug
) || die ("invalid options");

my $border = int($width * 0.01);
$height = int($width / 32 * 9) * 2 unless ($height);

# read sequence from file / return array of lines
sub read_file ($)
{
	my $filename = $_[0];
	my @ret;

	open (FILE, "<", "$filename");
	while (<FILE>)
	{
		push(@ret, $_)
	}
	close (FILE);

	return @ret;
}

# return subroutine
sub get_sub ($$)
{
	my $name = $_[0];
	my @data = @{$_[1]};

	my $pos = 0;
	my $in = 0;
	my @sub;

	while ($pos < @data)
	{
		if ($data[$pos] =~ /^DEFSUB,\s*$name\s*(?:;.*)?$/)	
		{
			$in = 1;
		}
		elsif ($in == 1)
		{

			if ($data[$pos] =~ /^ENDSUB\s*(?:;.*)?$/)	
			{
				return @sub;
			}
			else
			{
				push(@sub, $data[$pos]);
			}		

		}
		$pos++;

	}
	die("invalid file");
}

# unfold all loops and sub-sequences
sub unfold($$)
{
	my @data = @{$_[0]};
	my @sub = @{$_[1]};

	my @ret;

	my $pos = 0;

	while (!( $sub[0] =~ /^END\s*(?:;.*)?$/))
	{
		unshift(@sub, pop(@data));
	}

	while ($pos < @data)
	{

		if ($data[$pos] =~ /^L, (\d*)\s*(?:;.*)?$/)
		{
			my $repeats = $1;
			my $level = 1;
			my @loop;

			$pos += 1;

			print "-L-\n" if ($debug);

			while ($level >= 1)
			{
				printf ("L %d %4d, %s", $level, $pos, $data[$pos]) if ($debug);

				push(@loop, $data[$pos]);

				$level += 1 if ($data[$pos] =~ /^L, (\d*)\s*(?:;.*)?$/);
				$level -= 1 if ($data[$pos] =~ /^E\s*(?:;.*)?$/);
				die("invalid file") if ($data[$pos] =~ /^END\s*(?:;.*)?$>/);
				die("invalid file") if ($pos >= @data);

				$pos += 1;
			}
			pop(@loop);
			push(@loop, "END\n");
			
			print ">L>\n" if ($debug);
			my @loop_unfolded = unfold(\@loop, \@sub);
			print "<L<\n" if ($debug);
			for (0 .. $repeats - 1)
			{
				push(@ret, @loop_unfolded);
			}

		}
		elsif ($data[$pos] =~ /^SUB,\s*([^\s;]*)\s*(?:;.*)?$/)
		{
			my $name = $1;
			
			print ">S>\n" if ($debug);
			my @sub_raw = get_sub($name, \@sub);
			my @sub_unfolded = unfold(\@sub_raw, \@sub);
			print "<S<\n" if ($debug);

			push(@ret, @sub_unfolded);

			$pos += 1;
		}
		elsif ($data[$pos] =~ /^END\s*(?:;.*)?$/)
		{
			return @ret;
		}
		else
		{
			push(@ret, $data[$pos]);
			$pos += 1;
		}

	}
	
	return @ret;

}

# create array (frames in defindes interval) of colors (RGB) from sequence
sub get_sequence($$)
{
	my @data = unfold($_[0], []);
	print "get sequence\n";

	my $res = 100;
	my $fps = $_[1];

	my @ret;

	my $pos = 0;
	my $time_real = 0;
	my $time_file = 0;

	my $r = 0;
	my $g = 0;
	my $b = 0;

	while ($pos < @data)
	{

		while ($time_real < $time_file)
		{
			printf("%s %s %s\n", $r, $g, $b) if ($debug);

			my @rgb=($r, $g, $b);
			push(@ret, \@rgb);

			$time_real += $res;
		}

		if ($data[$pos] =~ /^D, (\d*)\s*(?:;.*)?$/)
		{
			$time_file += $1 * $fps;
			$pos += 1;
		}
		elsif ($data[$pos] =~ /^R, (\d*)\s*(?:;.*)?$/)
		{
			$r = $1;
			$pos +=1;
		}
		elsif ($data[$pos] =~ /^G, (\d*)\s*(?:;.*)?$/)
		{
			$g = $1;
			$pos +=1;
		}
		elsif ($data[$pos] =~ /^B, (\d*)\s*(?:;.*)?$/)
		{
			$b = $1;
			$pos +=1;
		}
		elsif ($data[$pos] =~ /^C, (\d*),\s*(\d*),\s*(\d*)\s*(?:;.*)?$/)
		{
			$r = $1;
			$g = $2;
			$b = $3;
			$pos +=1;
		}
		elsif ($data[$pos] =~ /^RAMP, (\d*),\s*(\d*),\s*(\d*),\s*(\d*)\s*(?:;.*)?$/)
		{
			my $start_r = $r;
			my $start_g = $g;
			my $start_b = $b;

			my $ramp_r = $1;
			my $ramp_g = $2;
			my $ramp_b = $3;
			my $ramp_d = $4;

			for (my $i = 0 ; $i <= $ramp_d * $fps - $res; $i += $res)
			{
				my $fade = $i / ($ramp_d * $fps);
				$r = int((1-$fade) * $start_r + $fade * $ramp_r);
				$g = int((1-$fade) * $start_g + $fade * $ramp_g);
				$b = int((1-$fade) * $start_b + $fade * $ramp_b);

				printf("%s %s %s (F)\n", $r, $g, $b) if ($debug);

				my @rgb=($r, $g, $b);
				push(@ret, \@rgb);

				$time_real += $res;
			}

			$r = $ramp_r;
			$g = $ramp_g;
			$b = $ramp_b;

			#$time_real += $ramp_d * $fps;
			$time_file += $ramp_d * $fps;
			$pos +=1;
		}
		else
		{
			$pos += 1;
		}

	}

	return @ret;

}

# getting multiple arrays of frame-arrays of color-arrays, write stream of png images to PIPE
sub draw(@)
{
	my @colors=@_;
	my $num=@colors;
	my @pallette;

	my $img = new GD::Image($width, $height);
	my $black = $img->colorAllocate(0,0,0);   

	for my $n (0 .. $num-1)
	{
		printf("%s %s %s\n", $colors[$n][0], $colors[$n][1], $colors[$n][2]) if ($debug);
		$pallette[$n] = $img->colorAllocate($colors[$n][0], $colors[$n][1], $colors[$n][2]);	
		$img->filledRectangle($width * $n / $num + $border, $border, $width * ($n+1) / $num - $border, $height - $border, $pallette[$n])
	}

	print (PIPE $img->png);

	for my $n (0 .. $num-1)
	{
		$img->colorDeallocate($pallette[$n])
	}
}

#####################################################

my @sequences;

foreach my $filename (@files)
{
	print $filename."\n";
	my @file = read_file($filename);
	my @sequence = get_sequence(\@file, $fps);

	push (@sequences, \@sequence);
}

my $count = @sequences;
my $length = @{$sequences[0]};
printf ("generated %s frames from %s files\n", $length, $count);

# amplify colors
if ($amplify)
{
	for my $i (0 .. @sequences - 1)
	{
		for my $j (0 .. @{$sequences[$i]} -1)
		{
			printf ("%03s %03s %03s - ", $sequences[$i][$j][0], $sequences[$i][$j][1], $sequences[$i][$j][2]) if ($debug);
			for (0 .. 2)
			{
				$sequences[$i][$j][$_] = int(sqrt($sequences[$i][$j][$_] / 255) * 255);
			}
			printf ("%03s %03s %03s\n", $sequences[$i][$j][0], $sequences[$i][$j][1], $sequences[$i][$j][2]) if ($debug);
		}
	}
}

# add audio input
my $avconv_audio;

if ($audio)
{
	$avconv_audio = "-i $audio";
}

# send all data to video encoding pipe
#open (PIPE, "|avconv -y -f image2pipe -vcodec png -r $fps -i - $avconv_audio -vcodec libx264 -preset slow -pix_fmt yuv420p -b:v 500k -r 30 -vf \"setsar=1:1\" -acodec libvo_aacenc -ac 2 -ar 44100 -ab 128k $output");
open (PIPE, "|avconv -y -f image2pipe -vcodec png -r $fps -i - $avconv_audio -vcodec libx264 -preset slow -pix_fmt yuv420p -b:v 500k -vf \"setsar=1:1\" -acodec libvo_aacenc -ac 2 -ar 44100 -ab 128k $output");
binmode PIPE;

for my $i (0 .. @{$sequences[0]} - 1)
{
	my @colors;
	for my $j (0 .. @sequences - 1)
	{
		push(@colors, $sequences[$j][$i]);
	}

	draw(@colors);
}

close (PIPE);

