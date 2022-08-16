#
# -- PublicDomain CC0 drit, 2022; https://creativecommons.org/publicdomain/zero/1.0/legalcode --
BEGIN { if (-e $ENV{SITE}.'/lib') { use lib $ENV{SITE}.'/lib'; } }

#
package secrets;
require Exporter;
@ISA = qw(Exporter);
# Subs we export by default.
@EXPORT = qw();
# Subs we will export if asked.
#@EXPORT_OK = qw(nickname);
@EXPORT_OK = grep { $_ !~ m/^_/ && defined &$_; } keys %{__PACKAGE__ . '::'};
push @EXPORT,'$secrets';

use strict;
our $seed = undef;

our $secrets = {
 hint => 'secret',
 code => "$ENV{SECRET_CODE}",
 default => "$ENV{DEFAULT_SECRET}", # for apiu:${creds}
 nosecret => 'polichinelle'
};

sub get_pass() {
  if (exists $ENV{ASK_PASS}) {
    local *EXEC;
    open EXEC,$ENV{ASK_PASS}.'|';
    my $pass = <EXEC>; chomp($pass);
    #debug qq'pass: %s\n',$pass;
    close EXEC;
    return $pass
  } else {
    require Term::ReadKey;
    Term::ReadKey::ReadMode('noecho');
    printf STDERR 'passwd: ';
    my $secret = Term::ReadKey::ReadLine(0);
    $secret =~ s/\R\z//;
    Term::ReadKey::ReadMode('restore');
    printf STDERR '*'x(length($secret)) . "\n";
    return $secret;
  }
}

