#!/usr/bin/perl


use YAML::XS qw(Dump DumpFile);

my $data = {};

my $kwhpbtc = 100168; # kWh/btc
my $cpbtc = 2454; # 2.454 tons CO2 per BTC
my $gpkwh = { # eqCO2: grams per kWh
  # https://www.carbonfootprint.com/docs/2019_06_emissions_factors_sources_for_2019_electricity.pdf
  hydro => 24.5, france => 47, switzerland => 14,
  germany => 469, us => 475.9, uk => 277.3,
  elec => 650, coal => 1000
};
my $cptree = 21; # removal 21kg / tree / year;

my $addr = shift || 'bc1q2zsysq8uh2xkuedn9kg725q259ge08gzn5lhjp' || 'bc1qugkdtcg8vr7j33leexstgk5gf3wgxcv5cajwps';
my $avtxn = &get_obj('https://blockchain.info/q/avgtxnumber');
my $totalbc = &get_obj('https://blockchain.info/q/totalbc') / 100000000;
#my $latesthash = &get_obj('https://blockchain.info/q/latesthash');
#my $height = &get_obj('https://blockchain.info/q/getblockcount');
my $breward = &get_obj('https://blockchain.info/q/bcperblock');

my $latestblock = &get_obj('https://blockchain.info/latestblock');
$latestblock->{nbtx} = scalar( @{$latestblock->{txIndexes}} );
delete $latestblock->{txIndexes};
my $latesthash = $latestblock->{hash};
my $height = $latestblock->{height};

my $cptx = $breward * $cpbtc / $avtxn; # in kg

printf "footprint-us: %s\n",$kwhpbtc * $gpkwh->{us} / 1000;
printf "footprint-germany: %s\n",$kwhpbtc * $gpkwh->{germany} / 1000;
printf "footprint-france: %s\n",$kwhpbtc * $gpkwh->{france} / 1000;
printf "footprint-switzerland: %s\n",$kwhpbtc * $gpkwh->{switzerland} / 1000;
printf "footprint-hydro: %s\n",$kwhpbtc * $gpkwh->{hydro} / 1000;
printf "footprint-coal: %s\n",$kwhpbtc * $gpkwh->{coal} / 1000;
my $footprint = $kwhpbtc * $gpkwh->{coal} / 1000;

printf "cpbtc: %s\n",$cpbtc;
printf "cptree: %s\n",$cptree;
printf "height: %s\n",$height;
printf "latesthash: %s\n",$latesthash;
printf "breward: %s\n",$breward;
printf "totalbc: %s\n",$totalbc;                #  tons     K      M      G      T      P
printf "totalco2: %s Mtons\n",$totalbc * $cpbtc / 1000 / 1000 / 1000; #/ 1000 / 1000 / 1000 ;
printf "avtxn: %s\n",$avtxn;
printf "cptx: %s\n",$cptx;
my $bal = &get_balance($addr);
my $rawaddr= &get_addr($addr);
my $fees = 0;
foreach my $tx (@{$rawaddr->{txs}}) {
  #printf "tx.balance: %s\n",$tx->{balance};
  $fees += $tx->{fee};
}

$tic = time();
$data = {
  tic => $tic, balance => $bal, kwhpbtc => $kwhpbtc, gpkwh => $gpkwh->{hydro},
  cptree => $cptree, addr => $addr, avtxn => $avtxn, totalbc => $totalbc,
  latestblock => $latestblock, breward => $breward,
  cptx => $cptx, footprint => $footprint,
  fees => $fees,
  totco2 => $totalbc * $cpbtc
};


printf "data: %s...\n",Dump($data);
DumpFile('oracle.yml',$data);


exit $?;

# https://blockchain.info/q/getblockcount
# https://blockchain.info/q/totalbc
# https://blockchain.info/q/avgtxnumber
# https://blockchain.info/q/addressfirstseen
# https://blockchain.info/q/txfee
# https://blockchain.info/q/latesthash
# https://blockchain.info/q/addressbalance
# https://blockchain.info/rawaddr/$bitcoin_address
# https://blockchain.info/unspent?active=$address
# https://blockchain.info/balance?active=$address

sub get_totalbc() {
 my $addr = shift;
 my $url = sprintf 'https://blockchain.info/q/totalbc';
 my $resp = &get_obj($url);
 return $resp;
}
sub get_avtxn() {
 my $url = sprintf 'https://blockchain.info/q/avgtxnumber';
 my $resp = &get_obj($url);
 return $resp;
}
sub get_addr($) {
 my $addr = shift;
 my $url = sprintf 'https://blockchain.info/rawaddr/%s',$addr;
 my $resp = &get_obj($url);
 #printf "rawaddr: %s...\n",Dump($resp);
 return $resp;
}
sub get_balance($) {
 my $addr = shift;
 my $url = sprintf 'https://blockchain.info/balance?active=%s',$addr;
 my $resp = &get_obj($url);
 printf "balance: %s...\n",Dump($resp);
 return $resp;
}

sub get_obj {
   my $url = shift;
   my $content = '400 Error';
   if ( iscached($url) ) {
     $content = get_cache($url);
   } else {
     use LWP::Simple qw(get);
     $content = get $url;
     warn "Couldn't get $url" unless defined $content;
     set_cache($url,$content);
   }
   my $obj = &objectify($content);
   return $obj;
}

sub jsonify {
   use JSON::XS qw();
   my $obj = shift;
   #y $json = encode_json( $obj ); # /!\ keys are not sorted !
   my $json = JSON::XS->new->canonical; # canonical : sort keys
   return $json->encode($obj);
}
sub objectify {
  my $content = shift;
  use JSON::XS qw(decode_json);
  if ($content =~ m/\}\n\{/m) { # nd-json format (stream)
    my $resp = [ map { &decode_json($_) } split("\n",$content) ] ;
    return $resp;
  } elsif ($content =~ m/^{/ || $content =~ m/^\[/) { # plain json]}
    #printf "[DBUG] Content: %s\n",$content;
    my $resp = &decode_json($content);
    return $resp;
  } elsif ($content =~ m/^--- /) { # /!\ need the trailing space
    use YAML::XS qw(Load);
    my $resp = Load($content);
    return $resp;
  } else {
    return $content;
  }
}

sub khash { # keyed hash
   use Crypt::Digest qw();
   my $alg = shift;
   my $data = join'',@_;
   my $msg = Crypt::Digest->new($alg) or die $!;
      $msg->add($data);
   my $hash = $msg->digest();
   return $hash;
}

sub iscached {
  my $url = shift;
  my $hash = &khash('SHA1','GET '.$url);
  my $file = sprintf 'cached/%s.dat',unpack'H*',$hash;
  return (-e $file)? 1 : 0;
}
sub get_cache {
  my $url = shift;
  my $hash = &khash('SHA1','GET '.$url);
  my $file = sprintf 'cached/%s.dat',unpack'H*',$hash;
  printf "use-cache: %s\n",$file;
  my $content = &readfile($file);
  return $content;
}
sub set_cache {
  my $url = shift;
  my $data = shift;
  my $hash = &khash('SHA1','GET '.$url);
  my $file = sprintf 'cached/%s.dat',unpack'H*',$hash;
  my $status = &writefile($file,$data);
  return $status;
}

sub readfile { # Ex. my $content = &readfile($filename);
  #y $intent = "read a (simple) file";
  my $file = shift;
  if (! -e $file) {
    print "// Error: readfile.file: ! -e $file\n";
    return undef;
  }
  local *F; open F,'<',$file; binmode(F);
  local $/ = undef;
  my $buf = <F>;
  close F;
  return $buf;
}

sub writefile { # Ex. &writefile($filename, $data1, $data2);
  #y $intent = "write a (simple) file";
  my $file = shift;
  local *F; open F,'>',$file; binmode(F);
  print "#// storing file: $file\n";
  for (@_) { print F $_; }
  close F;
  return $.;
}
# ------------------------
1;
