#!/usr/bin/perl -w

# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not 
# use this file except in compliance with the License. A copy of the License 
# is located at
#
#        http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE" file accompanying this file. This file is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
# express or implied. See the License for the specific language governing 
# permissions and limitations under the License.

our $usage = <<USAGE;

Usage: mon-put-instance-data.pl [options]

  Collects memory, swap, and disk space utilization on an Amazon EC2
  instance and sends this data as custom metrics to Amazon CloudWatch.

Description of available options:

  --mem-util          Reports memory utilization in percentages.
  --mem-used          Reports memory used (excluding cache and buffers) in megabytes.
  --mem-avail         Reports available memory (including cache and buffers) in megabytes.
  --swap-util         Reports swap utilization in percentages.
  --swap-used         Reports allocated swap space in megabytes.
  --disk-path=PATH    Selects the disk by the path on which to report.
  --disk-space-util   Reports disk space utilization in percentages.  
  --disk-space-used   Reports allocated disk space in gigabytes.
  --disk-space-avail  Reports available disk space in gigabytes.

  --memory-units=UNITS      Specifies units for memory metrics.
  --disk-space-units=UNITS  Specifies units for disk space metrics.
  
    Supported UNITS are bytes, kilobytes, megabytes, and gigabytes.

  --aws-credential-file=PATH  Specifies the location of the file with AWS credentials.
  --aws-access-key-id=VALUE   Specifies the AWS access key ID to use to identify the caller.
  --aws-secret-key=VALUE      Specifies the AWS secret key to use to sign the request.

  --from-cron  Specifies that this script is running from cron.
  --verify     Checks configuration and prepares a remote call.
  --verbose    Displays details of what the script is doing.
  --version    Displays the version number.
  --help       Displays detailed usage information.
  
Examples
 
 To perform a simple test run without posting data to Amazon CloudWatch
 
  ./mon-put-instance-data.pl --mem-util --verify --verbose
 
 To set a five-minute cron schedule to report memory and disk space utilization to CloudWatch
  
  */5 * * * * ~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --disk-space-util --disk-path=/ --from-cron

For more information on how to use this utility, see Amazon CloudWatch Developer Guide at
http://docs.amazonwebservices.com/AmazonCloudWatch/latest/DeveloperGuide/mon-scripts-perl.html

USAGE

use strict;
use warnings;
use Switch;
use Getopt::Long;
use File::Basename;
use Sys::Hostname;
use Sys::Syslog qw(:DEFAULT setlogsock);
use Sys::Syslog qw(:standard :macros);

BEGIN
{
  my $script_dir = &File::Basename::dirname($0);
  push @INC, $script_dir;
}

use CloudWatchClient;

use constant
{
  KILO => 1024,
  MEGA => 1048576,
  GIGA => 1073741824,
};

my $version = '1.0.1';
my $client_name = 'CloudWatch-PutInstanceData';

my $mcount = 0;
my $report_mem_util;
my $report_mem_used;
my $report_mem_avail;
my $report_swap_util;
my $report_swap_used;
my $report_disk_util;
my $report_disk_used;
my $report_disk_avail;
my @mount_path;
my $mem_units;
my $disk_units;
my $mem_unit_div = 1;
my $disk_unit_div = 1;
my $from_cron;
my $verify;
my $verbose;
my $show_help;
my $show_version;
my $enable_compression;
my $aws_credential_file;
my $aws_access_key_id;
my $aws_secret_key;
my $parse_result = 1;
my $parse_error = '';
my $argv_size = @ARGV;

{
  # Capture warnings from GetOptions
  local $SIG{__WARN__} = sub { $parse_error .= $_[0]; };

  $parse_result = GetOptions(
    'help|?' => \$show_help,
    'version' => \$show_version,
    'mem-util' => \$report_mem_util,
    'mem-used' => \$report_mem_used,
    'mem-avail' => \$report_mem_avail,
    'swap-util' => \$report_swap_util,
    'swap-used' => \$report_swap_used,
    'disk-path:s' => \@mount_path,
    'disk-space-util' => \$report_disk_util,
    'disk-space-used' => \$report_disk_used,
    'disk-space-avail' => \$report_disk_avail,
    'memory-units:s' => \$mem_units,
    'disk-space-units:s' => \$disk_units,
    'verify' => \$verify,
    'from-cron' => \$from_cron,
    'verbose' => \$verbose,
    'aws-credential-file:s' => \$aws_credential_file,
    'aws-access-key-id:s' => \$aws_access_key_id,
    'aws-secret-key:s' => \$aws_secret_key,
    'enable-compression' => \$enable_compression);
}

# Prints out or logs an error and then exits.
sub exit_with_error
{
  my $message = shift;
  report_message(LOG_ERR, $message);
 
  if (!$from_cron) {
    print STDERR "\nFor more information, run 'mon-put-instance-data.pl --help'\n\n";
  }

  exit 1;
}

# Prints out or logs a message.
sub report_message
{
  my $log_level = shift;
  my $message = shift;
  chomp $message;
 
  if ($from_cron)
  {
    setlogsock('unix');
    openlog($client_name, 'nofatal', LOG_USER);
    syslog($log_level, $message);
    closelog;
  }
  elsif ($log_level == LOG_ERR) {
    print STDERR "\nERROR: $message\n";
  }
  elsif ($log_level == LOG_WARNING) {
    print "\nWARNING: $message\n";
  }
  elsif ($log_level == LOG_INFO) {
    print "\nINFO: $message\n";
  }
}

if (!$parse_result) {
  exit_with_error($parse_error);
}
if ($show_version) {
  print "\n$client_name version $version\n\n";
  exit 0;
}
if ($show_help || $argv_size < 1) {
  print $usage;
  exit 0;
}
if ($from_cron) {
  $verbose = 0;
}

# check for empty values in provided arguments
if (defined($aws_credential_file) && length($aws_credential_file) == 0) {
  exit_with_error("Path to AWS credential file is not provided.");
}
if (defined($aws_access_key_id) && length($aws_access_key_id) == 0) {
  exit_with_error("Value of AWS access key id is not specified.");
}
if (defined($aws_secret_key) && length($aws_secret_key) == 0) {
  exit_with_error("Value of AWS secret key is not specified.");
}
if (defined($mem_units) && length($mem_units) == 0) {
  exit_with_error("Value of memory units is not specified.");
}
if (defined($disk_units) && length($disk_units) == 0) {
  exit_with_error("Value of disk space units is not specified.");
}

# check for inconsistency of provided arguments
if (defined($aws_credential_file) && defined($aws_access_key_id)) {
  exit_with_error("Do not provide AWS credential file and AWS access key id options together.");
}
elsif (defined($aws_credential_file) && defined($aws_secret_key)) {
  exit_with_error("Do not provide AWS credential file and AWS secret key options together.");
}
elsif (defined($aws_access_key_id) && !defined($aws_secret_key)) {
  exit_with_error("AWS secret key is not specified.");
}
elsif (!defined($aws_access_key_id) && defined($aws_secret_key)) {
  exit_with_error("AWS access key id is not specified.");
}

# decide on the reporting units for memory and swap usage
if (!defined($mem_units) || lc($mem_units) eq 'megabytes') {
  $mem_units = 'Megabytes';
  $mem_unit_div = MEGA;
}
elsif (lc($mem_units) eq 'bytes') {
  $mem_units = 'Bytes';
  $mem_unit_div = 1;
}
elsif (lc($mem_units) eq 'kilobytes') {
  $mem_units = 'Kilobytes';
  $mem_unit_div = KILO;
}
elsif (lc($mem_units) eq 'gigabytes') {
  $mem_units = 'Gigabytes';
  $mem_unit_div = GIGA;
}
else {
  exit_with_error("Unsupported memory units '$mem_units'. Use Bytes, Kilobytes, Megabytes, or Gigabytes.");
}

# decide on the reporting units for disk space usage
if (!defined($disk_units) || lc($disk_units) eq 'gigabytes') {
  $disk_units = 'Gigabytes';
  $disk_unit_div = GIGA;
}
elsif (lc($disk_units) eq 'bytes') {
  $disk_units = 'Bytes';
  $disk_unit_div = 1;
}
elsif (lc($disk_units) eq 'kilobytes') {
  $disk_units = 'Kilobytes';
  $disk_unit_div = KILO;
}
elsif (lc($disk_units) eq 'megabytes') {
  $disk_units = 'Megabytes';
  $disk_unit_div = MEGA;
}
else {
  exit_with_error("Unsupported disk space units '$disk_units'. Use Bytes, Kilobytes, Megabytes, or Gigabytes.");
}

my $df_path = '';
my $report_disk_space;
foreach my $path (@mount_path) {
  if (length($path) == 0) {
    exit_with_error("Value of disk path is not specified.");
  }
  elsif (-e $path) {
    $report_disk_space = 1;
    $df_path .= ' '.$path;
  }
  else {
    exit_with_error("Disk file path '$path' does not exist or cannot be accessed.");
  }
}

if ($report_disk_space && !$report_disk_util && !$report_disk_used && !$report_disk_avail) {
  exit_with_error("Disk path is provided but metrics to report disk space are not specified.");
}
if (!$report_disk_space && ($report_disk_util || $report_disk_used || $report_disk_avail)) {
  exit_with_error("Metrics to report disk space are provided but disk path is not specified.");
}

# check that there is a need to monitor at least something
if (!$report_mem_util && !$report_mem_used && !$report_mem_avail
  && !$report_swap_util && !$report_swap_used && !$report_disk_space)
{
  exit_with_error("No metrics specified for collection and submission to CloudWatch.");
}

my $now = time();
my $timestamp = CloudWatchClient::get_timestamp($now);
my $instance_id = CloudWatchClient::get_instance_id();

if (!defined($instance_id) || length($instance_id) == 0) {
  exit_with_error("Cannot obtain instance id from EC2 meta-data.");
}

my %params = ();
$params{'Action'} = 'PutMetricData';
$params{'Namespace'} = 'System/Linux';

#
# Adds a new metric to the CloudWatch request.
#
sub append_metric
{
  my $name = shift;
  my $unit = shift;
  my $value = shift;
  my $filesystem = shift;
  my $mount = shift;
  my $dimmcount = 0;
  
  ++$mcount;
  $params{"MetricData.member.$mcount.MetricName"} = $name;
  $params{"MetricData.member.$mcount.Timestamp"} = $timestamp;
  $params{"MetricData.member.$mcount.Value"} = $value;
  $params{"MetricData.member.$mcount.Unit"} = $unit;
  
  $dimmcount = 1;
  $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Name"} = 'InstanceId';
  $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Value"} = $instance_id;
  
  if ($filesystem)
  {
    ++$dimmcount;
    $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Name"} = 'Filesystem';
    $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Value"} = $filesystem;
  }  
  if ($mount)
  {
    ++$dimmcount;
    $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Name"} = 'MountPath';
    $params{"MetricData.member.$mcount.Dimensions.member.$dimmcount.Value"} = $mount;
  }

  print "$name [$mount]: $value ($unit)\n" if ($verbose && $mount);
  print "$name: $value ($unit)\n" if ($verbose && !$mount);
}

# avoid a storm of calls at the beginning of a minute
if ($from_cron) {
  sleep(rand(20));
}

# collect memory and swap metrics

if ($report_mem_util || $report_mem_used || $report_mem_avail || $report_swap_util || $report_swap_used)
{
  my %meminfo;
  foreach my $line (split('\n', `/bin/cat /proc/meminfo`)) {
    if($line =~ /^(.*?):\s+(\d+)/) {
      $meminfo{$1} = $2;
    }
  }

  # meminfo values are in kilobytes
  my $mem_total = $meminfo{'MemTotal'} * KILO;
  my $mem_free = $meminfo{'MemFree'} * KILO;
  my $mem_cached = $meminfo{'Cached'} * KILO;
  my $mem_buffers = $meminfo{'Buffers'} * KILO;
  my $mem_avail = $mem_free + $mem_cached + $mem_buffers;
  my $mem_used = $mem_total - $mem_avail;
  my $swap_total = $meminfo{'SwapTotal'} * KILO;
  my $swap_free = $meminfo{'SwapFree'} * KILO;  
  my $swap_used = $swap_total - $swap_free;
  
  if ($report_mem_util) {
    my $mem_util = 0;
    $mem_util = 100 * $mem_used / $mem_total if ($mem_total > 0);
    append_metric('MemoryUtilization', 'Percent', $mem_util);
  }
  if ($report_mem_used) {
    append_metric('MemoryUsed', $mem_units, $mem_used / $mem_unit_div);
  }
  if ($report_mem_avail) {
    append_metric('MemoryAvailable', $mem_units, $mem_avail / $mem_unit_div);
  }

  if ($report_swap_util) {
    my $swap_util = 0;
    $swap_util = 100 * $swap_used / $swap_total if ($swap_total > 0);
    append_metric('SwapUtilization', 'Percent', $swap_util);
  }
  if ($report_swap_used) {
    append_metric('SwapUsed', $mem_units, $swap_used / $mem_unit_div);
  }
}

# collect disk space metrics

if ($report_disk_space)
{
  my @df = `/bin/df -k -l -P $df_path`;
  shift @df;

  foreach my $line (@df)
  {
    my @fields = split('\s+', $line);
    # Result of df is reported in 1k blocks
    my $disk_total = $fields[1] * KILO;
    my $disk_used = $fields[2] * KILO;
    my $disk_avail = $fields[3] * KILO;
    my $fsystem = $fields[0];
    my $mount = $fields[5];
    
    if ($report_disk_util) {
      my $disk_util = 0;
      $disk_util = 100 * $disk_used / $disk_total if ($disk_total > 0);
      append_metric('DiskSpaceUtilization', 'Percent', $disk_util, $fsystem, $mount);
    }
    if ($report_disk_used) {
      append_metric('DiskSpaceUsed', $disk_units, $disk_used / $disk_unit_div, $fsystem, $mount);
    }
    if ($report_disk_avail) {
      append_metric('DiskSpaceAvailable', $disk_units, $disk_avail / $disk_unit_div, $fsystem, $mount);
    }
  }
}

# send metrics over to CloudWatch if any

if ($mcount > 0)
{
  my %opts = ();
  $opts{'aws-credential-file'} = $aws_credential_file;
  $opts{'aws-access-key-id'} = $aws_access_key_id;
  $opts{'aws-secret-key'} = $aws_secret_key;
  $opts{'short-response'} = 1;
  $opts{'retries'} = 2;
  $opts{'verbose'} = $verbose;
  $opts{'verify'} = $verify;
  $opts{'user-agent'} = "$client_name/$version";
  $opts{'enable_compression'} = 1 if ($enable_compression);

  my ($code, $reply) = CloudWatchClient::call(\%params, \%opts);
  
  if ($code == 200 && !$from_cron) {
    if ($verify) {
      print "\nVerification completed successfully. No actual metrics sent to CloudWatch.\n\n";
    } else {
      print "\nSuccessfully reported metrics to CloudWatch. Reference Id: $reply\n\n";
    }
  }
  elsif ($code < 100) {
    exit_with_error("Failed to initialize: $reply");
  }
  elsif ($code != 200) {
    exit_with_error("Failed to call CloudWatch: HTTP $code. Message: $reply");
  }
}
else {
  exit_with_error("No metrics prepared for submission to CloudWatch.");
}

exit 0;
