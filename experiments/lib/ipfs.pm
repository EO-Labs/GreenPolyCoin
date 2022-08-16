#!perl


BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }
#
package ipfs;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;
use basic qw(debug version);
sub dlog(@);

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');
printf STDERR "--- # %s: %s %s\n",__PACKAGE__,$VERSION,join', ',caller(0)||caller(1);
# -----------------------------------------------------------------------

# ---------------------------------------
sub ipfsPeerId() { # Ex. my $peerid = &ipfsPeer();
   my $resp = &ipfsapi('config',arg => 'Identity.PeerID');
   return $resp->{Value};
}
# ---------------------------------------
sub ipfsExist(@) { # Ex. my $status = &ipfsExist($hash);
   #y $intent = "test if IPFS hash exists";
   my $ipath = shift;
   my $args = { @_ };
   my $timeout = $args->{timeout} || '5s';
   $ipath = '/ipfs/'.$ipath if ($ipath !~ m,^/,);
   my $mh = &ipfsapi('files/stat', 'arg' => $ipath, 'cid-base' => 'base58flickr', 'timeout' => $timeout);
   return wantarray ? %$mh : $mh->{Hash};
}
# ---------------------------------------
sub ipfsConnect(@) { # Ex. my $mh = &ipfsConnect($peer);
   my $intent = "connect to a peer";
   my $args = { @_ };
   my ($peer,$layer);
   if (defined $args->{peer}) {
      $peer = $args->{peer};
      $layer = $args->{layer} || 'tcp/\d+' ;
   } else {
      ($peer,$layer) = (@_,'tcp/\d+');
   }
   # ipfs dht findpeer
   my $peers = &ipfsapi('dht/findpeer', arg => $peer, timeout => '19s');
   my $nodes = [ grep { $_->{Type} == 2; } @$peers];
   if (! scalar(@$nodes)) {
     return { peer => $peer, msg => "peer unreachable" };
   }
   my $addrs = $nodes->[-1]{Responses}[0]{Addrs};
   my $addr = ( grep m/${layer}$/, grep !m{/ip4/127\.}, grep !m{::1}, @$addrs )[0];
   # ipfs swarm connect
   $addr .= '/p2p/'.$peer;
   my $resp = &ipfsapi('swarm/connect', arg => $addr);
   my $status = ($resp->{Strings} =~ /success/) ? 0 : 1;
   return { status => $status, msg => $resp->{Strings}, addr => $addr} ;
}
# ---------------------------------------
# ---------------------------------------
sub ipfsToken { # public token (footprint)
  my $mh;
  my $urn;
  my $args = { @_ };
  #dlog "args: [%s]",join',',%{$args};
  if (! exists $args->{urn}) {
     $urn = shift;
     $args = { @_ };
  } else {
     $urn = $args->{urn};
  }
  #y intent qq"compute: time expiring token %s",$urn;
  my $ttl = $args->{TTL} || $ENV{TOKEN_TTL} || 24 * 3593; # default ~1day
  my $timeint = int (time / $ttl + 0.499) ; # /!\ can be future time !
  my $slug = $urn; $slug =~ s/\W+/-/g;
  use keys qw(KHMAC);
  my $key = pack'N',$timeint;
  my $token = &KHMAC('SHA256',$key,$urn);
  if ($args->{set}) {
     use basic qw(ldate);
     dlog "set: token %s @%s\n",$urn,ldate($timeint * $ttl);
    $mh = &ipfsapi('add', 'raw-leaves' => 'true', 'cid-base' => 'base58flickr', filename => "$slug.dat", Content => $token);
  } else {
     dlog "get: token %s @%s\n",$urn,ldate($timeint * $ttl);
    $mh = &ipfsapi('add', 'raw-leaves' => 'true', 'cid-base' => 'base58flickr', 'only-hash' => 'true', Content => $token);
  }
  if (ref($mh) eq 'HASH') {
    dlog "hash: %s\n",$mh->{Hash};
  }
  return $mh
}
# ---------------------------------------
sub ipfsFetch($) { # Ex. my $blob = &ipfsFetch($ipath);
   #y $intent "get content from an ipfs path";
   my $ipath = shift;
   return &ipfsapi('cat',arg => '/ipfs/'.$ipath);
}

sub ipfsPull($) { # Ex. my $bloob = &ipfsFetch($mhash);
   #y $intent = "get content from a hash";
   my $hash = shift;
   return &ipfsapi('cat',arg => $hash);
}
sub ipfsPush($) { # Ex. my $mh = &ipfsPush($data);
   #y $intent = "push content to IPFS";
   my $content = shift;
   # Content-Disposition: form-data; name="file"; filename="folderName"
   # Content-Type: application/x-directory
   #
   # Abspath: /absolute/path/to/file.txt or url
   # Content-Disposition: form-data; name="file"; filename="folderName%2Ffile.txt"
   # Content-Type: application/octet-stream
   my $mh = &ipfsapi('add', 'raw-leaves' => 'true', 'cid-base' => 'base58flickr', Content => $content);
   return $mh;
}
# ---------------------------------------
sub ipfsapi {
   my $api_url;
   #y $callee = (&callee())[0];
   # ipfs config Addresses.API
   my ($apihost,$apiport) = &get_apihostport();
   if ($apiport =~ m/443/) {
      $api_url = sprintf'https://%s:%s/api/v0/%%s?%%s',$apihost,$apiport;
   } else {
      $api_url = sprintf'http://%s:%s/api/v0/%%s?%%s',$apihost,$apiport;
   }
   my $ep = shift; # endpoint
   my $params = [ @_ ];
   my $args = { @_ };
   my $uploads = {};
   if ($params->[-2] eq 'Content') {
      $uploads = { (splice @$params, -2) };
   }
   use JSON::XS qw(encode_json);
   dlog "endpoint: %s\n",$ep;
   if (exists $args->{arg}) {
      dlog "arg: %s\n",$args->{arg}
   } else {
     dlog "params: %s\n",encode_json($params);
   }
   my  $buf = undef;
   if (keys %{$uploads}) {
      log "uploads.keys: %s\n",join',',keys %{$uploads};
      if (exists $uploads->{Content}) {
         $buf = $uploads->{Content};
         if ($buf =~ /[\000-\031\177-\377]/o) { # binary ?
            my $b64 = encode_base64($buf,'');
            dlog "uploads.buf: %s..%s\n",substr($b64,0,10),substr($b64,-43);
         } else {
            dlog "uploads.buf: %s..%s\n",substr($buf,0,10),substr($buf,-43);
         }
      }
   }
   my $query_string = &querify($params);
   my $url = sprintf $api_url,$ep,$query_string;
   dlog "url: %s\n",$url;
   my $content = '';
   use basic qw(get_creds);
   use LWP::UserAgent qw();
   use MIME::Base64 qw(decode_base64 encode_base64);
   my $ua = LWP::UserAgent->new();
   my $basic_auth = &get_creds();
   dlog "basic_auth: %s\n",$basic_auth;
   if (0) {
      my ($user,$pass) = split':',&decode_base64($basic_auth);
      my $realm = 'restricted API Gateway';
      $ua->credentials("$apihost:$apiport", $realm, ${user}, $pass);
      dlog "X-User: %s\n",$user;
      dlog "X-Creds: %s\n",encode_base64(sprintf'%s:%s',$ua->credentials("$apihost:$apiport",$realm),'');
   }
   my @headers = ('Authorization' => "Basic $basic_auth", 'Origin' => 'http://localhost:8088');
   my $resp;
   if ($buf) {
      push @headers, 'Content_Type' => 'multipart/form-data';
      # see also:
      # - [RFC 1867](https://datatracker.ietf.org/doc/html/rfc1867)
      # - [HTTP Request](https://metacpan.org/pod/HTTP::Request::Common)
      my $filename = $args->{filename} || 'blob.data';
      dlog "X-filename: %s\n",$filename;
      my $form_ref = { file => [ undef, $filename, 'Content-Type' => 'application/stream', Content => $buf ] }; 
      $resp = $ua->post($url,@headers, Content => $form_ref);
   } else {
      push @headers, 'Content_Type' => 'text/plain';
      $resp = $ua->post($url,@headers);
   }
   if ($resp->is_success) {
      dlog("%s.status: %s\n",$ep, $resp->status_line);
      $content = $resp->decoded_content;
   } else {
      dlog "X-api-url: %s\n",$url;
      dlog "Status: %s\n",$resp->status_line;
      $content = $resp->decoded_content;
      local $/ = "\n";
      chomp($content);
   }
   if ($ep =~ m{^(?:cat)}) {
      dlog "content: %s...\n",substr($content,0,24);
      return $content;
   }
   use JSON::XS qw(decode_json encode_json);
   if ($content =~ m/\}\n\{/m) { # nd-json format (stream)
      my $json = [ map { &decode_json($_) } split("\n",$content) ] ;
      return $json;
   } elsif ($content =~ m/^{/) { # plain json}
      #printf "[DBUG] Content: %s\n",$content;
      my $json = &decode_json($content);
      if (exists $json->{Code}) { # percolate any errors
         if ($json->{Message} =~ m/not exist/) {
            $json->{status} = 404;
         } elsif ($resp->is_error) {
            $json->{status} = $resp->code;
            $json->{status_line} = $resp->status_line;
         }
      } else {
        $json->{status} = $resp->code;
        $json->{Message} = $resp->status_line;
      }
      dlog "json: %s\n",&encode_json($json);
      return $json;
   } elsif ($content =~ m/^--- /) { # /!\ need the trailing space
      use YAML::XS qw(Load);
      my $yaml = Load($content);
      $yaml->{status} = $resp->code; # pass error along...
      dlog "yaml: %s\n",&encode_json($yaml);
      return $yaml;
   } else {
      dlog "info: $ep no content returned\n" if (! $content);
      return $content;
   }
}
# ---------------------------------------
sub get_apihostport {
  # grab local config file
  # obviously it requires a local IPFS node runing 
  if (! exists $ENV{IPFS_API_GATEWAY}) {
     my $IPFS_PATH = $ENV{IPFS_PATH} || $ENV{HOME}.'/.ipfs';
     #dlog "IPFS_PATH: %s\n",$IPFS_PATH;
     if (-e $IPFS_PATH.'/api') {
        local *API; open API,'<',$IPFS_PATH.'/api';
        my $apiaddr = <API>; chomp($apiaddr);
        my (undef,undef,$apihost,undef,$apiport) = split'/',$apiaddr,5;
        $apihost = '127.0.0.1' if ($apihost eq '0.0.0.0');
        return ($apihost,$apiport);
     } else {
        my $conff = $IPFS_PATH . '/config';
        local *CFG; open CFG,'<',$conff or warn $!;
        local $/ = undef; my $buf = <CFG>; close CFG;
        use JSON::XS qw(decode_json);
        my $json = decode_json($buf);
        my $apiaddr = $json->{Addresses}{API};
        my (undef,undef,$apihost,undef,$apiport) = split'/',$apiaddr,5;
        $apihost = '127.0.0.1' if ($apihost eq '0.0.0.0');
        return ($apihost,$apiport);
     }
  } else {
     my ($apihost,$apiport) = ($1,$2) if ($ENV{IPFS_API_GATEWAY} =~ m,https?://([^:]+):(\d+),);
     return ($apihost,$apiport);
  }
}

sub querify { # Ex. my $query = querify($params);
  #y $intent = q"querify a key-value map";
  my @queries = ();
  my @params;
  if (ref($_[0]) eq 'HASH') {
    @params = ( %{$_[0]} );
   } else {
    @params = ( @{$_[0]} );
   }
  while (@params) {
    my $k = shift @params;
    my $v = shift @params;
    #$v =~ s/([\000-\032\`%?&\<\( \)\>\177-\377])/sprintf('%%%02X',ord($1))/eg; # html-ize (url-encode)
    push @queries, "$k=$v";
  }
  if (@queries) {
    return join'&',@queries;
  } else {
    return undef;
  }
}
sub mapify { # Ex. my $map = mapify($params);
  my @params;
  if (ref($_[0]) eq 'ARRAY') {
    @params = ( @{$_[0]} );
   } else {
    return $_[0];
   }
   my $map = {};
  while (@params) {
    my $k = shift @params;
    my $v = shift @params; 
    if (exists $map->{$k}) { 
      if (ref($map->{$k}) ne 'ARRAY') {
        $map->{$k} = [ $map->{$k}, $v ];
      } else {
        push @{$map->{$k}}, $v;
      }
    } else {
      $map->{$k} = $v;
    }
  }
  return $map;
}


sub dlog(@) {
  our $DLOG;
  use Time::HiRes qw(time);
  my $tics = time();
  my $ticns = $tics * 1000_000;
  if (!tell($DLOG)) {
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = (gmtime(int$tics));
     my $DLOGF = sprintf"%s/_data/dlogs-D%d.yml",$ENV{SITE},$yday+1; $DLOGF =~ s,_site/,,;
     open $DLOG,'>>',$DLOGF or warn $!; binmode($DLOG, ":utf8");
     my $h = select $DLOG; $|=1; select($h); # autoflush for $DLOG
  }
  my $callee = (caller(1))[3];
  $callee =~ s/.*:://o;
  my $fmt = shift;
  if ($fmt !~ m/\n$/) { $fmt .= "\n"; }
  printf $DLOG '%u:%s.'.$fmt,$ticns,$callee,@_;
}

# -----------------------------------------------------------------------
1; # $Source: /my/perl/modules/ipfs.pm $

