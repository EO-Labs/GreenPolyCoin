#
# Intent:
#  create keys for file encryption and provide user keys to decrypt it.
#
# Note:
#   This work has been done during my time freelancing
#   for PaladinAI at Toptal as Doctor I·T
# 
# -- PublicDomain CC0 drit, 2021; https://creativecommons.org/publicdomain/zero/1.0/legalcode --
BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }
#
package keys;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};

use strict;
use basic qw(debug version);

# The "use vars" and "$VERSION" statements seem to be required.
use vars qw/$dbug $VERSION/;
# ----------------------------------------------------
our $VERSION = sprintf "%d.%02d", q$Revision: 0.0 $ =~ /: (\d+)\.(\d+)/;
my ($State) = q$State: Exp $ =~ /: (\w+)/; our $dbug = ($State eq 'dbug')?1:0;
# ----------------------------------------------------
$VERSION = &version(__FILE__) unless ($VERSION ne '0.00');
printf STDERR "--- # %s: %s %s\n",__PACKAGE__,$VERSION,join', ',caller(0)||caller(1);
# -----------------------------------------------------------------------

use YAML::XS qw(Dump);
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);
use Bitcoin::Mnemonic qw(entropy_to_bip39_mnemonic bip39_mnemonic_to_entropy gen_bip39_mnemonic);

our $appid = $ENV{APP_SECRETID} || '59d95bef-71f3-44e9-ae61-78dab20711d8';

# -----------------------------------------------
# ex: xdg-open http://0.0.0.0:5000/?seed=abcd1234edfg5678 (12 words min)
sub getMnemonic {
  my $data = shift;
  my $data_raw = ($data =~ m/^m/ && length($data) % 16) ? &decode_mbase64($data) :
                 ($data =~ m/^Z/ && length($data) % 16 ) ? &decode_mbase58($data) :
                 ($data =~ m/^f[0-9a-z]+$/ && length($data) % 2 ) ? pack('H*',$data) :
                  $data;

  printf "data_raw: %s\n",unpack'H*',$data_raw;
  debug qq'compute memonic for %s',&encode_mbase64($data_raw);
  my $mnemonic = &entropy_to_bip39_mnemonic (entropy => $data_raw, language => 'en');
  debug "mnemonic: %s\n",$mnemonic;
  return $mnemonic;
}
sub getEntropy {
  my $obj = shift;
  my $mnemo;
  if (ref($obj) eq 'ARRAY') {
     $mnemo = join' ',@{$obj};
  } elsif (ref($obj) eq 'HASH') {
     $mnemo = join' ',@{$obj->{mnemonic};
  }

}
# -----------------------------------------------
sub getPublicKey($) {
   #y $intent qq'compute keypair from a uuid';
   my $uuid = shift;
   my $uuid16 = $uuid; $uuid16 =~ tr/-//d;
   debug "uuid16: f%s (%dc)\n",$uuid16, length($uuid16);
   my $uuid_raw = pack'H*',$uuid16;
   my $uuid58 = &encode_mbase58($uuid_raw);
   debug "uuid: %s (%dB)\n",$uuid58, length($uuid_raw);
   my $ns = sprintf "uuid %d\0", length($uuid_raw);
   my $khash = substr(&khash('SHA256',$ns,$uuid_raw),0,240/8);
   my $salt = random(2);
   debug "salt: %s\n",unpack'H*',$salt;
   my $sku_raw = $khash.$salt;
   my $sku = encode_mbase58($khash.$salt);
   debug "sku: %s\n",$sku;

   my $keypair = &ECC($sku_raw);
   use Time::HiRes qw(time);
   my $tics = time;
   my $ticns = $tics * 1000_000;

   $keypair->{timestamp} = $ticns;

   if (wantarray) {
      my $mnemo = getMnemonic($uuid_raw);
      debug 'mnemo %s',$mnemo;
      $keypair->{mnemonic} = $mnemo;
      debug "keypair: %s---\n",Dump($keypair);
      return %{$keypair};
   } else {
      return $keypair->{public};
   }
}
# -----------------------------------------------
sub ECC {
   my $curve = 'secp256k1';
   use Crypt::PK::ECC;
   my $pk = Crypt::PK::ECC->new();
   my $secretkey = shift;
   my ($private_raw,$public_raw);
   if (defined $secretkey) { # key derivation ...
      my $sku_raw = &decode_mbase58($secretkey);
      my $priv = $pk->import_key_raw($sku_raw, $curve);
      $private_raw = $priv->export_key_raw('private_compressed');
      debug "private: %s (imported)",&encode_mbase58($private_raw);
   } else { # key generation ...
      $pk->generate_key($curve);
      $private_raw = $pk->export_key_raw('private_compressed');
   }
   my $seckey58 = &encode_mbase58($private_raw);
   my $public_raw = $pk->export_key_raw('public_compressed');
   my $pubkey58 = &encode_mbase58($public_raw);
   my $pair = {
      curve => $curve,
      public => $pubkey58,
      private => $seckey58,
   };
   return $pair;
}
# -----------------------------------------------
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
  my ($pubkey58,$privkey58) = @_;
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

sub encode_mbase64 {
  use MIME::Base64 qw(encode_base64);
  my $mh = sprintf'm%s',&encode_base64(join('',@_),'');
  $mh =~ s/=+$//;
  return $mh;
}
sub decode_mbase64 {
  use MIME::Base64 qw(decode_base64);
  return &decode_base64(substr($_[0],1));
}
# ------------------------------------------------
sub encode_mbase58 {
  my $mh = sprintf'Z%s',&encode_base58f(@_);
  return $mh;
}
sub decode_mbase58 {
  return &decode_base58(substr($_[0],1));
}
# ------------------------------------------------
sub encode_base58f { # flickr
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $bin = join'',@_;
  my $bint = Math::BigInt->from_bytes($bin);
  my $h58 = Encode::Base58::BigInt::encode_base58($bint);
  # $h58 =~ tr/a-km-zA-HJ-NP-Z/A-HJ-NP-Za-km-z/; # btc
  return $h58;
}
sub decode_base58f {
  use Carp qw(cluck);
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $s = $_[0];
  #$s =~ tr/A-HJ-NP-Za-km-zIO0l/a-km-zA-HJ-NP-ZiooL/; # btc
  $s =~ tr/IO0l/iooL/; # forbidden chars
  #printf "s: %s\n",unpack'H*',$s;
  my $bint = Encode::Base58::BigInt::decode_base58($s) or warn "$s: $!";
  cluck "error decoding $s!" unless $bint;
  my $bin = Math::BigInt->new($bint)->as_bytes();
  return $bin;
}
# ------------------------------------------------




