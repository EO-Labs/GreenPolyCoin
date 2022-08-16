#!/usr/local/bin/plackup
#
# env SITE=$(git rev-parse --show-toplevel) plackup signup.psgi
BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }

use Plack::Request;

our $intent = 'secure self sovereign identity login';
my $usage = 'app/login.html';

delete $ENV{CDPATH};
delete $ENV{LS_COLORS};

# // CGI compatibility :)
if ($ENV{GATEWAY_INTERFACE} eq 'CGI/1.1') {
  my @resp = $app->(\%ENV);
  print "\r\n" if $dbug;
  printf "Status: %s OK!\r\n",$resp[0];
  print join"\r\n",$resp[1];
  print "\r\n";
  print $resp[2][0];

}
# -----------------------------------------------------------------------
# PSGI application :
my $app = sub {
   use YAML::XS qw(Dump);
   use JSON::XS qw(encode_json);
   use MIME::Base64 qw(encode_base64);
   my $env = shift; # PSGI env
   my $req = Plack::Request->new($env);
   my $params = $req->parameters();
   #y $uploads = $req->uploads();
   
   my $status = 200;
   my $headers = [ ];

   $obj = { message => "hello, World" };

   push @$headers, 'Content-Type' => 'application/json';
   my $json = JSON::XS->new->canonical; # canonical : sort keys
   $body = $json->encode($obj);
   return [ $status, $headers, [ $body ]];
};

# -----------------------------------------------------------------------
if (! exists $ENV{PLACK_ENV} && "$0" eq __FILE__ ) {
   printf "--- # env %s---\n",Dump(\%ENV);
   $| = 1;
   printf "--- # app %s...",Dump($app->());
} else {
  return $app;
}
# -----------------------------------------------------------------------
$app;

