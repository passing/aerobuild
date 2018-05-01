#!/usr/bin/perl
use strict;
use Getopt::Long;
use GD;

my $input;
my $output;
my $num=1;
my $debug=0;
my $interval=10;
my $max_error=0;
my $error_ratio=1;
my $repeat=1;

GetOptions (
	'input=s' => \$input,
	'output=s' => \$output,
	'num=i' => \$num,
	'interval=i' => \$interval,
	'error=i' => \$max_error,
	'ratio=i' => \$error_ratio,
	'repeat=i' => \$repeat,
	'debug' => \$debug
) || die ("invalid options");

GD::Image->trueColor(1);
my $img;

if ($input =~ /\.png$/)
{
	$img = newFromPng GD::Image($input) || die;
}
elsif ($input =~ /\.jpe?g$/)
{
    $img = newFromJpeg GD::Image($input) || die;
}
elsif ($input =~ /\.gif$/)
{
    $img = newFromGif GD::Image($input) || die;
}
else
{
	die;
}

my $width = $img->width;
my $height = $img->height;

printf ("image: %s\n", $input);
printf ("size: %d x %d\n", $width, $height);

my $x;
my $y;

printf ("interval: %d/100 s\n", $interval);
printf ("duration: %d x %.1fs = %.1fs\n", $repeat, $width * $interval / 100, $repeat * $width * $interval / 100);
print ("\n");

my @sequences;

### import

for my $n (0 .. $num -1)
{
	my @sequence;

	$y = $height * ((0.5 + $n) / $num);
	printf ("line %2d: %4d\n", $n, $y);

	for $x (0 .. $width-1)
	{
		my $index = $img->getPixel($x,$y);
		my @drgb = ($x, $img->rgb($index));
		push (@sequence, \@drgb);

		#printf ("%4d: %03d %03d %03d\n", @drgb) if ($debug);
	}
	push (@sequences, \@sequence);
}

### analyze

for my $i (0 .. @sequences - 1)
{
    for my $j (1 .. @{$sequences[$i]} - 2)
    {

		my $e_pos = 0;
		my $e_neg = 0;

		for my $k (1 .. 3)
		{
			my $c_diff = (0.0 + $sequences[$i][$j-1][$k] + $sequences[$i][$j+1][$k]) / 2 - $sequences[$i][$j][$k];

			if ($c_diff >= 0)
			{
				$e_pos = $c_diff if ($c_diff > $e_pos);
			}
			else
			{
				$e_neg = $c_diff if ($c_diff < $e_neg);
			}
		}

		$sequences[$i][$j][4] = $e_pos - $e_neg;
    }
}

if ($max_error >= 0)
{

### compress

for my $i (0 .. @sequences - 1)
{
	my $joined = 0;
	my $j = 1;
	while ($j <= @{$sequences[$i]} - 2)
    {
		if (
			(1.0 / $error_ratio * $joined + 1) * $sequences[$i][$j][4] <= $max_error
		)
		{
			$sequences[$i][$j-1][4] += 1.0 * $sequences[$i][$j][4];
			$sequences[$i][$j+1][4] += 1.0 * $sequences[$i][$j][4];
			splice(@{$sequences[$i]}, $j, 1);

			$joined += 1;
		}
		else
		{
			$j++;
			$joined = 0;
		}
    }
}

### merge duplicates
for my $i (0 .. @sequences - 1)
{
	my $j = 2;
	while ($j <= @{$sequences[$i]} - 2)
    {
		if (
			$sequences[$i][$j-1][1] == $sequences[$i][$j][1] &&
			$sequences[$i][$j-1][2] == $sequences[$i][$j][2] &&
			$sequences[$i][$j-1][3] == $sequences[$i][$j][3] &&
			$sequences[$i][$j-2][1] == $sequences[$i][$j][1] &&
			$sequences[$i][$j-2][2] == $sequences[$i][$j][2] &&
			$sequences[$i][$j-2][3] == $sequences[$i][$j][3]
		)
		{
			splice(@{$sequences[$i]}, $j, 1);
		}
		else
		{
			$j++;
		}
    }
}

}

### output

open (FILE, ">", $output) || die;

printf (FILE "; image: %s\n", $input);
printf (FILE "L, %d\n", $repeat) if ($repeat > 1);

for my $i (0 .. @sequences - 1)
{
	printf ("= %d =\n", $i) if ($debug);
	printf (FILE "<%d>\n", $i+1);
    for my $j (0 .. @{$sequences[$i]} - 1)
    {
		my $delta = ($j == 0 ? 1 : $sequences[$i][$j][0] - $sequences[$i][$j-1][0]);
		printf("%4d: %4d - %03d %03d %03d - %3d - %f\n", $j, $sequences[$i][$j][0], $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta, $sequences[$i][$j][4]) if ($debug);

		#if ($j == 0)
		#{
		#	printf (FILE "RAMP, %d, %d, %d, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
		#	#printf (FILE "C, %d, %d, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3] );
		#	#printf (FILE "C, %d, %d, %d\nD, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
		#}
		#elsif (

		if (
			$j > 0 &&
			$sequences[$i][$j-1][1] == $sequences[$i][$j][1] &&
			$sequences[$i][$j-1][2] == $sequences[$i][$j][2] &&
			$sequences[$i][$j-1][3] == $sequences[$i][$j][3]
		)
		{
			printf (FILE "D, %d\n", $delta * $interval );
		}
#		elsif ($delta * $interval == 1)
#		{
#			if (
#				$sequences[$i][$j-1][2] == $sequences[$i][$j][2] &&
#				$sequences[$i][$j-1][3] == $sequences[$i][$j][3]
#			)
#			{
#				printf (FILE "R, %d\nD, %d\n", $sequences[$i][$j][1], $delta * $interval );
#			}
#			elsif (
#				$sequences[$i][$j-1][1] == $sequences[$i][$j][1] &&
#				$sequences[$i][$j-1][3] == $sequences[$i][$j][3]
#			)
#			{
#				printf (FILE "G, %d\nD, %d\n", $sequences[$i][$j][2], $delta * $interval );
#			}
#			elsif (
#				$sequences[$i][$j-1][1] == $sequences[$i][$j][1] &&
#				$sequences[$i][$j-1][2] == $sequences[$i][$j][2]
#			)
#			{
#				printf (FILE "B, %d\nD, %d\n", $sequences[$i][$j][3], $delta * $interval );
#			}
#			else
#			{
#				printf (FILE "RAMP, %d, %d, %d, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
#				#printf (FILE "C, %d, %d, %d\nD, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
#			}
#		}
		else
		{
			printf (FILE "RAMP, %d, %d, %d, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
			#printf (FILE "C, %d, %d, %d\nD, %d\n", $sequences[$i][$j][1], $sequences[$i][$j][2], $sequences[$i][$j][3], $delta * $interval );
		}
    }
}

printf (FILE "<end>\n");
printf (FILE "E\n") if ($repeat > 1);
printf (FILE "END\n");

close (FILE);

print "\n";

for my $i (0 .. @sequences - 1)
{
	my $l = @{$sequences[$i]};
	printf ("commands %2d: %4d\n", $i, $l);
}
