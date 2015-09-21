#!/usr/bin/perl -w

# Copyright 2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

Usage: mon-get-instance-stats.pl [options]

  Queries Amazon CloudWatch for statistics on CPU, memory, swap, and
  disk space utilization within a given time interval. This data is
  provided for the Amazon EC2 instance on which this script is executed.

Description of available options:

  --recent-hours=N  Specifies the number of recent hours to report.
  --verify          Checks configuration and prepares remote calls.
  --verbose         Displays details of what the script is doing.
  --version         Displays the version number.
  --help            Displays detailed usage information.
  
  --aws-credential-file=PATH  Specifies the location of the file with AWS credentials.
  --aws-access-key-id=VALUE   Specifies the AWS access key ID to use to identify the caller.
  --aws-secret-key=VALUE      Specifies the AWS secret key to use to sign the request.
  --aws-iam-role=VALUE        Specifies the IAM role used to provide AWS credentials.
  
For more information on how to use this utility, see Amazon CloudWatch Developer Guide at
http://docs.amazonwebservices.com/AmazonCloudWatch/latest/DeveloperGuide/mon-scripts-perl.html

USAGE

use strict;
use warnings;
use Switch;
use File::Basename;
use Getopt::Long;
use Sys::Hostname;
use Sys::Syslog qw(:DEFAULT setlogsock);
use Sys::Syslog qw(:standard :macros);

BEGIN
{
  my $script_dir = &File::Basename::dirname($0);
  push @INC, $script_dir;
}

use CloudWatchClient;

my $version = '1.1.0';
my $client_name = 'CloudWatch-GetInstanceStats';

my $verify;
my $verbose;
my $show_help;
my $show_version;
my $recent_hours = 1;
my $aws_credential_file;
my $aws_access_key_id;
my $aws_secret_key;
my $aws_iam_role;
my $parse_result = 1;
my $parse_error = '';

{
  # Capture warnings from GetOptions
  local $SIG{__WARN__} = sub { $parse_error .= $_[0]; };

  $parse_result = GetOptions(
    'help|?' => \$show_help,
    'version' => \$show_version,
    'recent-hours=n' => \$recent_hours,
    'verify' => \$verify,
    'verbose' => \$verbose,
    'aws-credential-file:s' => \$aws_credential_file,
    'aws-access-key-id:s' => \$aws_access_key_id,
    'aws-secret-key:s' => \$aws_secret_key,
    'aws-iam-role:s' => \$aws_iam_role);
}

sub exit_with_error
{
  my $message = shift;
  chomp $message;
  print STDERR "\nERROR: $message\n";
  print STDERR "\nFor more information, run 'mon-get-instance-stats.pl --help'\n\n";
  exit 1;
}
  
if (!$parse_result) {
  exit_with_error($parse_error);
}
if ($show_version) {
  print "\n$client_name version $version\n\n";
  exit 0;
}
if ($show_help) {
  print $usage;
  exit 0;
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
if (defined($aws_iam_role) && length($aws_iam_role) == 0) {
  exit_with_error("Value of AWS IAM role is not specified.");
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
elsif (defined($aws_iam_role) && defined($aws_credential_file)) {
  exit_with_error("Do not provide AWS IAM role and AWS credential file options together.");
}
elsif (defined($aws_iam_role) && defined($aws_secret_key)) {
  exit_with_error("Do not provide AWS IAM role and AWS access key id/secret key options together.");
}


my $now = time();
my $timestamp = CloudWatchClient::get_timestamp($now);
my $instance_id = CloudWatchClient::get_instance_id();

if (!defined($instance_id) || length($instance_id) == 0) {
  exit_with_error("Cannot obtain instance id from EC2 meta-data.");
}

#
# Makes a remote call to CloudWatch.
#
sub call_cloud_watch
{
  my $params = shift;

  my %call_opts = ();
  $call_opts{'aws-credential-file'} = $aws_credential_file;
  $call_opts{'aws-access-key-id'} = $aws_access_key_id;
  $call_opts{'aws-secret-key'} = $aws_secret_key;
  $call_opts{'short-response'} = 0;
  $call_opts{'retries'} = 1;
  $call_opts{'verbose'} = $verbose;
  $call_opts{'verify'} = $verify;
  $call_opts{'user-agent'} = "$client_name/$version";
  $call_opts{'aws-iam-role'} = $aws_iam_role;
  
  my ($response_code, $response_content) = CloudWatchClient::call($params, \%call_opts);
  
  if ($response_code < 100) {
    exit_with_error("Failed to initialize: $response_content");
  }
  elsif ($response_code != 200) {
    $response_content =~ /<Message>(.*?)<\/Message>/s;
    $response_content = $1 if $1;
    exit_with_error("Failed to call CloudWatch service with HTTP status code $response_code. Message: $response_content");
  }
  
  return $response_content;
}

#
# Fetches stats from CloudWatch for a given metric
# and reports its avg, min, and max values.
#
sub print_metric_stats
{
  my $namespace = shift;
  my $metric = shift;
  my $title = shift;
  my $extra_dims = shift;

  my $start_time = CloudWatchClient::get_timestamp($now - $recent_hours * 3600);
  my $end_time = CloudWatchClient::get_timestamp($now);
  
  my %params = ();
  $params{'Action'} = 'GetMetricStatistics';
  $params{'Namespace'} = $namespace;
  $params{"MetricName"} = $metric;
  $params{"Period"} = '300';
  $params{"Statistics.member.1"} = 'Average';
  $params{"Statistics.member.2"} = 'Maximum';
  $params{"Statistics.member.3"} = 'Minimum';
  $params{"StartTime"} = $start_time;
  $params{"EndTime"} = $end_time;
  $params{"Dimensions.member.1.Name"} = 'InstanceId';
  $params{"Dimensions.member.1.Value"} = $instance_id;

  if (defined $extra_dims) {
    my %all_params = (%params, %$extra_dims);
    %params = %all_params;
  }
  
  my $reply = call_cloud_watch(\%params);
  
  my $min;
  my $max;
  my $avg;
  my $count = 0;
  
  while ($reply =~ /<Average>(.*?)<\/Average>/g) {
    ++$count;
    $avg = 0 if !defined $avg;
    $avg += $1;
  }
  $avg /= $count if $count > 0;
  
  while ($reply =~ /<Minimum>(.*?)<\/Minimum>/g) {
    if (!defined($min) || $min > $1) {
      $min = $1;
    }
  }  
  
  while ($reply =~ /<Maximum>(.*?)<\/Maximum>/g) {
    if (!defined($max) || $max < $1) {
      $max = $1;
    }
  }
  
  print "\n$title\n    ";
  print "Average: ";
  if (defined $avg) {
    printf "%.2f%%, ", $avg;
  } else {
    print "N/A, ";
  }
  print "Minimum: ";
  if (defined $min) {
    printf "%.2f%%, ", $min;
  } else {
    print "N/A, ";
  }
  print "Maximum: ";
  if (defined $max) {
    printf "%.2f%%\n", $max;
  } else {
    print "N/A\n";
  }
  print "\n" if ($verbose);
}

#
# Finds the metric for filesystem mounted on /
# and reports disk space utilization on it.
#
sub print_filesystem_stats
{
  my $namespace = 'System/Linux';
  my $metric_name = 'DiskSpaceUtilization';

  my %params = ();
  $params{'Action'} = 'ListMetrics';
  $params{'Namespace'} = $namespace;
  $params{"MetricName"} = $metric_name;
  $params{"Dimensions.member.1.Name"} = 'InstanceId';
  $params{"Dimensions.member.1.Value"} = $instance_id;
  $params{"Dimensions.member.2.Name"} = 'MountPath';
  $params{"Dimensions.member.2.Value"} = '/';
  
  my $reply = call_cloud_watch(\%params);
  
  if ($reply =~ /<Value>\/dev\/(.*?)<\/Value>/) {
    my $filesystem = "/dev/$1";
    my %extra_dims = ();
    $extra_dims{"Dimensions.member.2.Name"} = 'MountPath';
    $extra_dims{"Dimensions.member.2.Value"} = '/';
    $extra_dims{"Dimensions.member.3.Name"} = 'Filesystem';
    $extra_dims{"Dimensions.member.3.Value"} = $filesystem;
    print_metric_stats($namespace, $metric_name,
      "Disk Space Utilization for $filesystem mounted on /", \%extra_dims);
  }
}

my $plural = ($recent_hours > 1 ? 's' : '');
print "\nInstance $instance_id statistics for the last $recent_hours hour$plural.\n";

print_metric_stats('AWS/EC2', 'CPUUtilization', 'CPU Utilization');
print_metric_stats('System/Linux', 'MemoryUtilization', 'Memory Utilization');
print_metric_stats('System/Linux', 'SwapUtilization', 'Swap Utilization');
print_filesystem_stats();

if ($verify) {
  print "\nVerification completed successfully. No actual calls were made to CloudWatch.\n";
}

print "\n";
exit 0;
