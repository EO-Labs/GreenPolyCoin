#!/usr/bin/perl
#!/usr/local/bin/plackup -s Gazelle
# env SITE=$(git rev-parse --show-toplevel) perl $SITE/psgi/code.psgi --port 5009
#  curl http://0:5009/
BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }

# use spot to create a secret code on the client that the server know too!
my $intent = "display mnemonic for a seed";

use YAML::XS qw();
use Plack::Request qw();

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



unless (caller) {
    require Plack::Runner;
    Plack::Runner->run(@ARGV, $0);
}

my $app = sub {
   use keys qw(getMnemonic);
   my $env = shift; # PSGI env
   my $req = Plack::Request->new($env);
   our $params = $req->parameters();

   my $headers = [ ];
   # prepare CORS header
   if (exists $env->{HTTP_ORIGIN}) {
      printf "HTTP_ORIGIN: %s\n",$env->{HTTP_ORIGIN};

      if ($env->{HTTP_ORIGIN} =~ /safewatch/ ) {
         $origin = $env->{HTTP_ORIGIN};
      } elsif ($env->{HTTP_ORIGIN} =~ /localhost/ ) {
         $origin = $env->{HTTP_ORIGIN};
      }
      push @$headers, 'Access-Control-Allow-Origin' => $origin;
   } else { # /!\ open to all non-originated request 
      push @$headers, 'Access-Control-Allow-Origin' => '*';
   }

   #printf "params: %s---\n",YAML::XS::Dump($params);
   my $mnemo = getMnemonic($params->{seed});
   my $obj = [split' ',$mnemo];

   use JSON::XS qw();
   my $json = JSON::XS->new->canonical; # canonical : sort keys
   push @$headers, 'Content-Type' => 'application/json';
   printf "headers: %s\n",YAML::XS::Dump($headers);
   return [200,$headers,[$json->encode($obj)]];
};


$app;
