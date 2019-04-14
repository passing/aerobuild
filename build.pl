#!/usr/bin/perl
use strict;
use Getopt::Long;

my $input = '';
my $num = 1;
my $debug = 0;
my $label_file;
my %labels;

my $res = 100;

GetOptions (
	'input=s' => \$input,
	'num=i' => \$num,
	'labels=s' => \$label_file,
	'debug' => \$debug
) || die ("invalid options");

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

# build multiple sequences based on tags
sub split_data ($$)
{
	my @data = @{$_[0]};
	my $num = $_[1];

	my @ret;

	my @last_active;
	my @active;
	for my $i (1 .. $num)
	{
		$active[$i] = 1;
	}

	foreach my $line (@data)
	{
		printf ("%s %s", join("", @active), $line) if ($debug);

		if ($line =~ /^<(.*)>$/)
		{
			my $cmd = $1;
			$line = "; $line";

			if ($cmd eq "end")
			{
				for my $i (1 .. $num)
				{
					$active[$i] = 1;
				}

				@last_active=();
			}
			elsif ($cmd eq "default")
			{
				for my $i (1 .. $num)
				{
					$active[$i]+=1 if ($active[$i] < 2);
				}
			}
			else
			{
				if (@last_active == 0)
				{
					for my $i (1 .. $num)
					{
						$active[$i]=0;
					}
				}
				else
				{
					foreach my $i (@last_active)
					{
						$active[$i]=2;
					}
				}

				my @now_active = split(",", $cmd);

				foreach my $i (@now_active)
				{
					$active[$i]=1;
				}

				@last_active = @now_active;
			}

		}

		for my $i (1 .. $num)
		{
			push(@{$ret[$i]}, $line) if ($active[$i] == 1); 
		}
	}

	return @ret;
}

# make 1/100 seconds readable
sub format_time ($)
{
	my $time = $_[0];
	my $min = $time / 6000;
	my $sec = $time / 100 % 60;
	my $hsec = $time % 100;

	return sprintf("%d:%02d.%02d", $min, $sec, $hsec);
}

# add timeline comments to sequence
sub add_timeline_comments ($$)
{
	my @data = @{$_[0]};
	my @timeline = @{$_[1]};

	my @ret;

	for my $i (0 .. @data -1)
	{
		push(@ret, sprintf ("; === %s ===\n", format_time($timeline[$i]))) if ($timeline[$i-1] != $timeline[$i] && $timeline[$i]);
		push(@ret, $data[$i]);
	}

	return @ret;
}

# write sequence to file
sub write_file ($$)
{
	my $filename = $_[0];
	my @data = @{$_[1]};

	open (FILE, ">", "$filename");
	foreach my $line (@data)
	{
		printf (FILE "%s", $line);
	}
	close (FILE);
}

# add delays to align to audacity labels
sub execute_labels ($$)
{
	my @data = @{$_[0]};
	my %labels = %{$_[1]};

	my @timeline = get_timeline(\@data, []);

	my @ret;
	my $pos = 0;
	my $time = 0;
	my $time_added = 0;

	while ($pos < @data)
	{
		my $line = $data[$pos];

		if ($timeline[$pos])
		{
			$time = $timeline[$pos]
		}

		if ($line =~ /^;(?:L-|LABEL )(\w*)(?: ([+-]?[0-9]+))?$/)
		{
			my $label = $1;
			my $delta = $2;
			my $t = $labels{$label};

			my $add = $t + $delta - $time - $time_added;

			printf ("Label %s: %d / %d%+d, add: %d\n", $label, $time + $time_added, $t, $delta, $add);

			die ("label exceeded") if ($add < 0);
			die ("delay exceeds 65535") if ($add > 65535);

			if ($t && $add > 0)
			{
				$line = sprintf("D, %d %s", $add, $line);
				$time_added += $add
			}
		}

		push(@ret, $line);
		$pos++;
	}

	return @ret;
}

# write multiple sequences to separate files adding timeline comments
sub write_files ($$$)
{
	my $filename = $_[0];
	my @data = @{$_[1]};
	my %labels = %{$_[2]};

	for my $i (1 .. @data-1)
	{
		my @data_i = @{$data[$i]};
		my $filename_num = $filename;
		my $fnum = sprintf("%02d", $i);
		$filename_num =~ s/\./_$fnum\./;

		if (%labels)
		{
			@data_i = execute_labels($data[$i], \%labels);
		}

		my @timeline = get_timeline(\@data_i, []);
		my @datat = add_timeline_comments(\@data_i, \@timeline);
		
		my $length = @datat;
		my $duration = $timeline[@timeline-1];
		printf "writing %s, %d lines, %s\n", $filename_num, $length, format_time($duration);

		write_file ($filename_num, \@datat);
	}
}

# get duration of sequence
sub get_duration ($$)
{
	my @timeline = get_timeline(@_);
	return pop(@timeline);
}

# get duration of sub-sequence
sub get_sub_duration ($$)
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
				return get_duration(\@sub, \@data);
			}
			else
			{
				push(@sub, $data[$pos]);
			}		

		}
		$pos++;

	}
	die("invalid file, sub $name");
}

# get timeline of sequence
sub get_timeline ($$)
{
	my @data = @{$_[0]};
	my @sub = @{$_[1]};

	my $duration = 0;
	my $pos = 0;
	my @timeline;

	while (!( $sub[0] =~ /^END\s*(?:;.*)?$/))
	{
		unshift(@sub, pop(@data));
		die "no END" if (@data == 0);
	}

	while ($pos < @data)
	{

		printf ("%4d, %6d, %s", $pos, $duration, $data[$pos]) if ($debug);

		if ($data[$pos] =~ /^D, (\d*)\s*(?:;.*)?$/)
		{
			$duration += $1;
			$pos += 1;
		}
		elsif ($data[$pos] =~ /^RAMP, (?:\d*), (?:\d*), (?:\d*), (\d*)\s*(?:;.*)?$/)
		{
			$duration += $1;
			$pos += 1;
		}
		elsif ($data[$pos] =~ /^L, (\d*)\s*(?:;.*)?$/)
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
				die("invalid file at $pos: $data[$pos]") if ($data[$pos] =~ /^END\s*(?:;.*)?$>/);
				die("invalid file at $pos: $data[$pos]") if ($pos >= @data);

				$pos += 1;
			}
			pop(@loop);
			push(@loop, "END\n");
			
			print ">L>\n" if ($debug);
			my $loop_duration = get_duration(\@loop, \@sub);
			print "<L<\n" if ($debug);
			$duration += $repeats * $loop_duration;

			printf ("L %d %d\n", $repeats, $loop_duration) if ($debug);

		#	$pos += 1;
		}
		elsif ($data[$pos] =~ /^SUB,\s*([^\s;]*)(?:;.*)?$/)
		{
			my $name = $1;
			
			print ">S>\n" if ($debug);
			my $sub_duration = get_sub_duration($name, \@sub);
			print "<S<\n" if ($debug);
			$duration += $sub_duration;

			printf ("S %d\n", $sub_duration) if ($debug);
			
			$pos += 1;
		}
		elsif ($data[$pos] =~ /^END\s*(?:;.*)?$/)
		{
			return @timeline;
		}
		elsif ($data[$pos] =~ /^[A-Za-z]$/)
		{
			die "invalid file at $pos: $data[$pos]:\n$data[$pos]";
		}
		else
		{
			$pos += 1;
		}

		$timeline[$pos] = $duration;
	}
	
	return @timeline;

}

# read audacity labels from file
sub read_labels($)
{
	my $filename = $_[0];
	my %labels;
	open (FILE, "<$filename") || die;
	while (<FILE>)
	{
		if ($_ =~ /^(.+)\t(.+)\t(.+)$/)
		{
			print("$1, $2, $3\n") if ($debug);
			$labels{$3} = int($1 * $res);
		}
	}
	close (FILE);
	return %labels;
}

#####################################################

print "$input $num\n";

if ($label_file)
{
	%labels = read_labels($label_file);
	if ($debug)
	{
		foreach my $key (keys(%labels))
		{
			print "$key $labels{$key}\n";
		}
	}
}

my @file = read_file($input);

my @split_files = split_data(\@file, $num);

write_files ($input, \@split_files, \%labels);

