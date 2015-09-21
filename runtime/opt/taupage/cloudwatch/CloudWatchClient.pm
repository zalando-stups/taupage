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

package CloudWatchClient;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw();
use Switch;
use File::Basename;
use Digest::SHA qw(hmac_sha256_base64);
use URI::Escape qw(uri_escape_utf8);
use Compress::Zlib;
use LWP 6;

use LWP::Simple qw($ua get);
$ua->timeout(2); # timeout for meta-data calls

our $client_version = '1.0.1';
our $service_version = '2010-08-01';
our $compress_threshold_bytes = 2048;
our $http_request_timeout = 5; # seconds

# RFC3986 unsafe characters
our $unsafe_characters = "^A-Za-z0-9\-\._~";

our $region;
our $avail_zone;
our $instance_id;

#
# Queries meta data on EC2 instance.
#
sub get_meta_data
{
  my $resource = shift;
  my $data_value = read_meta_data($resource);
  
  if (!defined($data_value) || length($data_value) == 0) {
    my $base_uri = 'http://169.254.169.254/latest/meta-data';
    $data_value = get $base_uri.$resource;
  }
  
  return $data_value;
}

#
# Reads meta-data from the local filesystem.
#
sub read_meta_data
{
  my $resource = shift;
  my $location = $ENV{'AWS_EC2CW_META_DATA'};
  my $data_value;

  if ($location)
  {
    my $filename = $location.$resource;
    if (-e $filename) {
      open MDATA, "$filename";
      $data_value = <MDATA>;
      close MDATA;
      chomp $data_value;
    }
  }
  
  return $data_value;
}

#
# Obtains EC2 instance id from meta data.
#
sub get_instance_id
{
  if (!$instance_id) {
    $instance_id = get_meta_data('/instance-id');
  }
  return $instance_id;
}

#
# Obtains EC2 avilability zone from meta data.
#
sub get_avail_zone
{
  if (!$avail_zone) {
    $avail_zone = get_meta_data('/placement/availability-zone');
  }
  return $avail_zone;
}

#
# Extracts region from avilability zone.
#
sub get_region
{
  if (!$region) {
    my $azone = get_avail_zone();
    if ($azone) {
      $region = substr($azone, 0, -1);
    }
  }
  return $region;
}

#
# Buids up the endpoint based on the provided region.
#
sub get_endpoint
{
  my $region = get_region();
  if ($region) {
    return "https://monitoring.$region.amazonaws.com/";
  }
  return 'https://monitoring.amazonaws.com/';
}

#
# Checks if credential set is present. If not, reads credentials from file.
#
sub prepare_credentials
{
  my $opts = shift;
  my $verbose = $opts->{'verbose'};
  my $outfile = $opts->{'output-file'};
  my $aws_access_key_id = $opts->{'aws-access-key-id'};
  my $aws_secret_key = $opts->{'aws-secret-key'};
  my $aws_credential_file = $opts->{'aws-credential-file'};
  
  if (defined($aws_access_key_id) && !$aws_access_key_id) {
    return(0, 'Provided empty AWS access key id.');
  }
  if (defined($aws_secret_key) && !$aws_secret_key) {
    return(0, 'Provided empty AWS secret key.');
  }  
  if ($aws_access_key_id && $aws_secret_key) {
    return(1, '');
  }
  
  if (!defined($aws_credential_file) || length($aws_credential_file) == 0) {
    my $env_creds_file = $ENV{'AWS_CREDENTIAL_FILE'};
    if (defined($env_creds_file) && length($env_creds_file) > 0) {
      $aws_credential_file = $env_creds_file;
    }
  }
  
  if (!defined($aws_credential_file) || length($aws_credential_file) == 0) {
    my $script_dir = &File::Basename::dirname($0);
    $aws_credential_file = $script_dir.'/awscreds.conf';
  }
  
  my $file = $aws_credential_file;
  open(FILE, '<:utf8', $file) or return(0, "Failed to open AWS credentials file <$file>");
  print_out("Using AWS credentials file <$aws_credential_file>", $outfile) if $verbose;
  
  while (my $line = <FILE>)
  {
    $line =~ /^$/ and next; # skip empty lines
    $line =~ /^#.*/ and next; # skip commented lines
    $line =~ /^\s*(.*?)=(.*?)\s*$/ or return(0, "Failed to parse AWS credential entry '$line' in <$file>.");
    my ($key, $value) = ($1, $2);
    switch ($key)
    {
      case 'AWSAccessKeyId' { $opts->{'aws-access-key-id'} = $value; }
      case 'AWSSecretKey'   { $opts->{'aws-secret-key'} = $value; }
    }
  }
  close (FILE);
  
  $aws_access_key_id = $opts->{'aws-access-key-id'};
  $aws_secret_key = $opts->{'aws-secret-key'};
  
  if (!defined($aws_access_key_id) || !$aws_access_key_id || !defined($aws_secret_key) || !$aws_secret_key) {
    return(0, "Provided incomplete AWS credential set in file <$file>.");
  }
  
  return (1, '');
}

#
# Returns UTC time in required format.
#
sub get_timestamp
{
  my $time = shift;
  sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
    sub {($_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0])}->(gmtime($time)));
}

#
# Prints out diagnostic message to a file or standard output.
#
sub print_out
{
  my $text = shift;
  my $filename = shift;
  
  if ($filename)
  {
    open OUT_STREAM, ">>$filename";
    print OUT_STREAM "$text\n";
    close OUT_STREAM;
  }
  else
  {
    print "$text\n";
  }
}

#
# Builds the service invocation payload including the signature.
#
sub build_payload
{
  my $params = shift;
  my $opts = shift;
  
  $params->{'AWSAccessKeyId'} = $opts->{'aws-access-key-id'};
  $params->{'Timestamp'} = get_timestamp(time());
  $params->{'Version'} = $opts->{'version'};
  $params->{'SignatureMethod'}  = 'HmacSHA256';
  $params->{'SignatureVersion'} = '2';

  my $endpoint = $opts->{'url'};
  my $endpoint_name = $endpoint;
  if ( !($endpoint_name =~ s!^https?://(.*?)/?$!$1!) ) {
    return (0, "Invalid AWS endpoint URL <$endpoint>");
  }

  my $sign_data = '';
  $sign_data .= 'POST';
  $sign_data .= "\n";
  $sign_data .= $endpoint_name;
  $sign_data .= "\n";
  $sign_data .= '/';
  $sign_data .= "\n";

  my @args = ();
  for my $key (sort keys %{$params}) {
    my $value = $params->{$key};
    my ($ekey, $evalue) = (uri_escape_utf8($key, $unsafe_characters), 
      uri_escape_utf8($value, $unsafe_characters));
    push @args, "$ekey=$evalue";
  }
  
  my $query_string = join '&', @args;
  $sign_data .= $query_string;
  
  my $signature = hmac_sha256_base64($sign_data, $opts->{'aws-secret-key'}).'=';
  my $payload = $query_string.'&Signature='.uri_escape_utf8($signature);
  
  return (1, $payload);
}

#
# Makes a remote invocation to CloudWatch service.
#
sub call
{
  my $params = shift;
  my $opts = shift;
  
  my $endpoint;
  if (defined($opts->{'url'})) {
    $endpoint = $opts->{'url'};
  }
  else {
    $endpoint = get_endpoint();
    $opts->{'url'} = $endpoint;
  }
  
  if (!defined($opts->{'version'})) {
    $opts->{'version'} = $service_version;
  }
  
  my $user_agent_string = "CloudWatch-Scripting/$client_version";
  if (defined($opts->{'user-agent'})) {
    $user_agent_string = $opts->{'user-agent'};
  }

  my $res_code;
  my $res_msg;
  my $payload;
  
  ($res_code, $res_msg) = prepare_credentials($opts);
  
  if ($res_code == 0) {
    return ($res_code, $res_msg);
  }
  
  ($res_code, $payload) = build_payload($params, $opts);
  
  if ($res_code == 0) {
    return ($res_code, $payload);
  }
  
  my $user_agent = new LWP::UserAgent(agent => $user_agent_string);
  $user_agent->timeout($http_request_timeout);
  my $request = new HTTP::Request 'POST', $endpoint;
  
  $request->content_type('application/x-www-form-urlencoded');
  $request->content($payload);
  
  if (defined($opts->{'enable-compression'}) && length($payload) > $compress_threshold_bytes) {
    $request->encode('gzip');
  }
  
  my $response;
  my $keep_trying = 1;
  my $call_attempts = 1;
  my $verbose = $opts->{'verbose'};
  my $outfile = $opts->{'output-file'};
  
  print_out("Endpoint: $endpoint", $outfile) if $verbose;
  print_out("Payload: $payload", $outfile) if $verbose;
  
  # initial and max delay in seconds between retries
  my $delay = 4; 
  my $max_delay = 16;
  
  if (defined($opts->{'retries'})) {
    $call_attempts += $opts->{'retries'};
  }  
  if (defined($opts->{'max-backoff-sec'})) {
    $max_delay = $opts->{'max-backoff-sec'};
  }

  my $response_code = 0;
  
  if ($opts->{'verify'}) {
    return (200, 'This is a verification run, not an actual response.');
  }
  
  for (my $i = 0; $i < $call_attempts && $keep_trying; ++$i)
  {
    my $attempt = $i + 1;
    $response = $user_agent->request($request);
    $response_code = $response->code;
    if ($verbose) {
      print_out("Received HTTP status $response_code on attempt $attempt", $outfile);
      if ($response_code != 200) {
        print_out($response->content, $outfile);
      }
    }
    $keep_trying = 0;
    if ($response_code >= 500) {
      $keep_trying = 1;
    } elsif ($response_code == 400) {
      # special case to handle throttling fault
      my $pattern = "<Code>Throttling<\/Code>";
      if ($response->content =~ m/$pattern/) {
        print_out("Request throttled.", $outfile) if $verbose;
        $keep_trying = 1;
      }
    }
    if ($keep_trying && $attempt < $call_attempts) {
      print_out("Waiting $delay seconds before next retry.", $outfile) if $verbose;
      sleep($delay);
      my $incdelay = $delay * 2;
      $delay = $incdelay > $max_delay ? $max_delay : $incdelay;
    }
  }
  
  my $response_content = $response->content;
  print_out($response_content, $outfile) if ($verbose && $response_code == 200);

  if ($opts->{'short-response'}) {
    my $pattern = $response->is_success ?
      "<RequestId>(.*?)<\/RequestId>" : "<Message>(.*?)<\/Message>";
    $response_content =~ /$pattern/s;
    if ($1) {
      $response_content = $1;
    }
  }

  return ($response->code, $response_content);
}

1;
