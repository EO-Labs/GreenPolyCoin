#!/usr/bin/env -S plackup -s Gazelle

=encoding utf8
=head2 
 usage:
=begin markdown

```sh
 SITE=$(git rev-parse --show-toplevel)/experiments
 env SITE=$SITE plackup ./app.psgi
 true; # vim: wrap
```
=end markdown

=cut

use Plack::App::File;
use Plack::App::DirectoryIndex;
use Plack::App::PSGIBin;
use Plack::App::URLMap;
use Plack::Util::Load qw();

require "./routes.pl";

my $headers = ['Content-Type' => 'text/plain'];

printf "--- # %s\n",$0;
# PSGI application :
my $app = $urlmap->to_app;

# -----------------------------------------------------------------------
if (! exists $ENV{PLACK_ENV} && "$0" eq __FILE__ ) {
   use YAML::XS qw(Dump);
   printf "--- # env %s---\n",Dump(\%ENV);
   $| = 1;
   printf "--- # app %s...",Dump($app->());
} else {
  return $app;
}
# -----------------------------------------------------------------------
$app;
