#
BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }

package basic;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');
printf STDERR "--- # %s: %s %s\n",__PACKAGE__,$VERSION,join', ',(caller(0)||caller(1));
# -----------------------------------------------------------------------
our $apicreds = '[CYPHER]c2NyeXB0AA8AAAAIAAAAAUcKJeX5Zur5AgVxL8D8RjoVxhYyPR5qLDTgxu6NGcrmJXoipg+977ZKq45NHz5aR8HZEizwNmkCwIQDvxrOgFdxvhmC2gjBXi9oxk7OpEE/eiWily2kF8zpBeLrZ3oHbnNU4SRgDCaOsdIeMiUN1xbNQSsXAKBGrw+R9Ynlj6ia47uSNA==[CLEAR]';
#
use Time::HiRes qw(time);
my $time = time;

our $DBUG;
#our $DBUGF = $ENV{SITE}."/_data/debug-$$.txt";
our $DBUGF = "debug.txt";
open $DBUG,'>>',$DBUGF or warn $!; binmode($DBUG, ":utf8");
my $h = select $DBUG; $|=1; select($h); # autoflush for $DBUG

sub debug(@) {
  my $callee = (caller(1))[3];
  $callee =~ s/.*:://o;
  my $tics = time();
  my $ticns = $tics * 1000_000;
  my $fmt = shift;
  if ($fmt !~ m/\n$/) { $fmt .= "\n"; }
  printf $DBUG '%u: %s.'.$fmt,$ticns,$callee,@_;
}
sub ldate { # return a human readable date ... but still sortable ...
  my $tic = int($_[0]);
  my ($sec,$min,$hour,$mday,$mon,$yy) = (localtime($tic))[0..5];
  my ($yr4,$yr2) =($yy+1900,$yy%100);
  my $date = sprintf '%04u-%02u-%02u %02u.%02u.%02u',
             $yr4,$mon+1,$mday, $hour,$min,$sec;
  return $date
}


sub get_creds($) {
  use secrets qw(get_pass);
  our $auth64;
  my $token = shift || $apicreds;
  if (! defined $auth64) {
    my $pass = &get_pass();
    # apiu:$apr1$s9BmOq49$y8Zmau6v6Hygv.lHNvhcg.
    $auth64 = &clarify($token,$pass);
  } else {
    debug "auth: %s\n",$auth64;
  }
  return $auth64;
}

sub clarify() { # Ex: my $clear = &clarify('[REDACTED]abc[CLEAR]');
 our $n;
 my $callee = 'clarify';
 use secrets qw();
 use Crypt::Scrypt;
 use MIME::Base64 qw(decode_base64 encode_base64);
 my ($string,$password) = @_;
 my $secret;
 if (defined $password && $password ne '') {
    debug qq'password: %s\n',$password;
    $secret = $password
 } else {
   $secret = $ENV{REDACTION_SECRET} || $secrets::secrets->{default};
   debug qq'secret: %s\n',$secret;
 }
 my $scrypt = Crypt::Scrypt->new(key => $secret, max_mem => 0, max_mem_frac => 0.5, max_time => 10);
 my $cipher64 = ($string =~ m/\[CIPHER](.*)\[CLEAR]/) ? $1 : encode_base64($scrypt->encrypt('unintelligible text'),'');
 my $cipher64p = $cipher64; $cipher64p =~ tr/+\//-_/;
 debug qq'string: %s\n',$string;
 debug qq'cipher64.%u: %s\n',$n++,$cipher64p; # n++ instead of time to test predictability
 my $cipher = decode_base64($cipher64);
 debug qq'cipher16: f%s\n',unpack'H*',$cipher;
 my $plain = $scrypt->decrypt($cipher);
 debug qq'plain: %s\n',$plain;
 return $plain
}

sub redact() {
 our $n;
 use secrets qw();
 use Crypt::Scrypt;
 use MIME::Base64 qw(encode_base64);
 my ($string,$password) = @_;
 my $secret = $password || $ENV{REDACTION_SECRET} || $secrets::secrets->{default};
 my $scrypt = Crypt::Scrypt->new(key => $password, max_mem => 0, max_mem_frac => 0.1, max_time => 2);
 my $plain = ($string =~ m/\[[^]]*REDACT[^]]*](.*)\[PLAIN]/) ? $1 : $string;

 my $cipher = $scrypt->encrypt($plain);
 my $cipher64 = encode_base64($cipher,'');
 printf qq'cipher64.%s: %s\n',$n++,$cipher64; # /!\ not deterministic !
 return sprintf '[CIPHER]%s[CLEAR]',$cipher64
}

sub KHMAC($$@) { # Ex. my $kmac = &KHMAC($algo,$secret,$nonce,$message);
  #y $intent = qq'to compute a keyed hash message authentication code';
  use Crypt::Mac::HMAC qw();
  my $algo = shift;
  my $secret = shift;
  #printf "KHMAC.secret: f%s\n",unpack'H*',$secret;
  my $digest = Crypt::Mac::HMAC->new($algo,$secret);
     $digest->add(join'',@_);
  return $digest->mac;
}

sub DHSecret { # Ex my $secret = DHSecret($sku,$pku);
  #y $intent = "reveals the share secret between 2 parties !";
  my ($privkey,$pubkey) = @_;
  my ($pubkey58,$privkey58);
  if (exists $keys->{$keyid} && defined $keys->{$keyid}{private}) {
    $privkey58 = $keys->{$keyid}{private};
  } elsif (exists $nicknames->{$keyid}) {
    $keyid = $nicknames->{$keyid};
    $privkey58 = $keys->{$keyid}{private};
  } else {
    $privkey58 = $keyid;
  }
  if (exists $nicknames->{$pubkey}) {
    $keyid = $nicknames->{$pubkey};
    $pubkey58 = $keys->{$keyid}{public};
  } elsif (exists $keys->{$pubkey} && defined $keys->{$pubkey}{public}) {
    $keyid = $pubkey;
    $pubkey58 = $keys->{$keyid}{public};
  } else {
    $pubkey58 = $keyid;
  }
  use encode qw(decode_mbase58 encode_mbase58);
  my $public_raw = &decode_mbase58($pubkey58);
  my $private_raw = &decode_mbase58($privkey58);

  my $curve = 'secp256k1';
  use Crypt::PK::ECC qw();
  my $sk  = Crypt::PK::ECC->new();
  my $priv = $sk->import_key_raw($private_raw, $curve);
  my $pk = Crypt::PK::ECC->new();
  my $pub = $pk->import_key_raw($public_raw ,$curve);
  my $shared_secret = $priv->shared_secret($pub);
  my $secret58 = &encode_mbase58($shared_secret);

  my $public = $priv->export_key_raw('public_compressed');
  my $public58 = &encode_mbase58($public);

  my $obj = {
    secret_raw => $shared_secret,
    origin => $public58,
    public => $pubkey58,
    secret => $secret58
  };
  return wantarray ? %{$obj} : $obj->{secret};
}




sub version {
  #y $intent = "get time based version string and a content based build tag";
  #y ($atime,$mtime,$ctime) = (lstat($_[0]))[8,9,10];
  my @times = sort { $a <=> $b } (lstat($_[0]))[9,10]; # ctime,mtime
  my $vtime = $times[-1]; # biggest time...
  my $version = &rev($vtime);

  if (wantarray) {
     my $shk = &get_shake(160,$_[0]);
     debug "%s : shk:%s\n",$_[0],$shk if $dbug;
     my $pn = unpack('n',substr($shk,-4)); # 16-bit
     my $build = &word($pn);
     return ($version, $build);
  } else {
     return sprintf '%g',$version;
  }
}
# -----------------------------------------------------------------------
sub rev { # get revision numbers
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday,$yday) = (localtime($_[0]))[0..7];
  my $rweek=($yday+&fdow($_[0]))/7;
  my $rev_id = int($rweek) * 4;
  my $low_id = int(($wday+($hour/24)+$min/(24*60))*4/7);
  my $revision = ($rev_id + $low_id) / 100;
  return (wantarray) ? ($rev_id,$low_id) : $revision;
}
# -----------------------------------------------------------------------
sub fdow { # get January first day of week
   my $tic = shift;
   use Time::Local qw(timelocal);
   ##     0    1     2    3    4     5     6     7
   #y ($sec,$min,$hour,$day,$mon,$year,$wday,$yday)
   my $year = (localtime($tic))[5]; my $yr4 = 1900 + $year ;
   my $first = timelocal(0,0,0,1,0,$yr4);
   our $fdow = (localtime($first))[6];
   #debug "1st: %s -> fdow: %s\n",&hdate($first),$fdow;
   return $fdow;
}
# -----------------------------------------------------------------------
sub get_shake { # use shake 256 because of ipfs' minimal length of 20Bytes
  use Crypt::Digest::SHAKE;
  my $len = shift;
  local *F; open F,$_[0] or do { warn qq{"$_[0]": $!}; return undef };
  #binmode F unless $_[0] =~ m/\.txt/;
  my $msg = Crypt::Digest::SHAKE->new(256);
  $msg->addfile(*F);
  my $digest = $msg->done(($len+7)/8);
  return $digest;
}
# -----------------------------------------------------------------------
sub keyw { # get a keyword from a hash (using 8 Bytes)
  my $hash=shift;
  my $o = (length($hash) > 11) ? -11 : -8;
  my $n = unpack'N',substr($hash,-$o,8);
  my $kw = &word($n);
  return $kw;
}
# -----------------------------------------------------------------------
sub word { # 20^4 * 6^3 words (25bit worth of data ...)
 use integer;
 my $n = $_[0];
 my $vo = [qw ( a e i o u y )]; # 6
 my $cs = [qw ( b c d f g h j k l m n p q r s t v w x z )]; # 20
 my $str = '';
 if (1 && $n < 26) {
 $str = chr(ord('a') +$n%26);
 } else {
 $n -= 6;
 while ($n >= 20) {
   my $c = $n % 20;
      $n /= 20;
      $str .= $cs->[$c];
   #print "cs: $n -> $c -> $str\n";
      $c = $n % 6;
      $n /= 6;
      $str .= $vo->[$c];
   #print "vo: $n -> $c -> $str\n";

 }
 if ($n > 0) {
   $str .= $cs->[$n];
 }
 return $str;
 }
}

# -----------------------------------------------------------------------
sub readfile { # Ex. my $content = &readfile($filename);
  #y $intent = "read a (simple) file";
  my $file = shift;
  if (! -e $file) {
    print "// Error: readfile.file: ! -e $file\n";
    return undef;
  }
  local *F; open F,'<',$file; binmode(F);
  debug "// reading file: $file\n";
  local $/ = undef;
  my $buf = <F>;
  close F;
  return $buf;
}
# -----------------------------------------------------------------------
sub writefile { # Ex. &writefile($filename, $data1, $data2);
  #y $intent = "write a (simple) file";
  my $file = shift;
  local *F; open F,'>',$file; binmode(F);
  debug "// storing file: $file\n";
  for (@_) { print F $_; }
  close F;
  return $.;
}
# -----------------------------------------------------------------------
sub appendfile { # Ex. &appendfile($filename, $data1, $data2);
  #y $intent = "append a file with data";
  my $file = shift;
  use Cwd qw(); my $pwd = &Cwd::cwd();
  if (! -e $file) {
    if ($file !~ m,^/,) {
      $file = $ENV{SITE} . '/' . $file;
    }
  }
  local *F; open F,'>>',$file or warn $!; binmode(F);
  debug "// appending file: $file (pwd: $pwd)";
  for (@_) { print F $_; }
  printf "at =%u.\n",tell(F);
  close F;
  return $.;
}
# -----------------------------------------------------------------------
1;
