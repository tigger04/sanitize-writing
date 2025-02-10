#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use Encode qw(decode encode);
use I18N::Langinfo qw(langinfo CODESET);
use File::Copy;
use File::Basename;
use Cwd 'abs_path';
use Getopt::Long;

# Decode command line arguments
@ARGV = map { decode("UTF-8", $_) } @ARGV;

# Get the absolute path of the script and its directory
my $script_path = abs_path($0);
my ($script_name, $script_dir) = fileparse($script_path);

# Parse command line arguments
my $config_file;
my $create_backup = 0;
my $backup_file;

GetOptions(
    "template=s" => \$config_file,
    "backup|b"   => \$create_backup,
    "backup-file=s" => \$backup_file
) or die "Error in command line arguments\n";

# Check if we have the text file argument
die "Usage: $0 --template=CONFIG_FILE [-b|--backup] [--backup-file=FILENAME] <text_file>\n" unless @ARGV == 1;

my $text_file = $ARGV[0];

# Check if files exist
die "Text file '$text_file' does not exist!\n" unless -f $text_file;
die "Config file '$config_file' does not exist!\n" unless -f $config_file;

# Handle backup if requested
if ($create_backup) {
    # If no backup filename specified, use default
    $backup_file //= $text_file . '.bak';
    
    # Create backup
    copy($text_file, $backup_file) or die "Backup failed: $!";
    print "Created backup: '$backup_file'\n";
}

# Read config file and create regex patterns
open my $config_fh, '<:encoding(UTF-8)', $config_file or die "Cannot open config file: $!";
my @patterns;
while (my $line = <$config_fh>) {
    chomp $line;
    # Skip empty lines and comments
    next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
    
    # Parse config line in format: search=replace
    if ($line =~ /^([^=]+)=(.+)$/) {
        my ($search, $replace) = ($1, $2);
        # Escape any regex special characters in search and replace
        $search = quotemeta($search);
        $replace = quotemeta($replace);
        # Create regex pattern with word boundaries and utf8 flag
        my $pattern = "s/\\b${search}\\b/${replace}/giu";  # Added 'u' flag
        push @patterns, $pattern;
    } else {
        warn "Invalid config line: $line\n";
    }
}
close $config_fh;

# Read the content of the text file
open my $text_fh, '<:encoding(UTF-8)', $text_file or die "Cannot open text file: $!";
my $content = do { local $/; <$text_fh> };
close $text_fh;

# Apply regex patterns to the content
foreach my $pattern (@patterns) {
    my $original = $content;
    eval "\$content =~ $pattern";
    if ($@) {
        warn "Error applying pattern '$pattern': $@\n";
    } else {
        # If content changed, report the pattern that caused the change
        if ($content ne $original) {
            my $count = 0;
            my ($search) = $pattern =~ m{^s/([^/]*)};  # Extract the search pattern
            # Count how many replacements were made
            $count++ while ($original =~ /$search/g);
            warn "Applied: $pattern ($count replacement(s))\n";
        }
    }
}

# Write modified content back to file
open my $out_fh, '>:encoding(UTF-8)', $text_file or die "Cannot write to text file: $!";
print $out_fh $content;
close $out_fh;

print "Processing complete.\n";
