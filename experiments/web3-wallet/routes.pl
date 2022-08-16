# Routes and App definitions

# application endpoints :
my $www = (-d "$ENV{SITE}/_site") ? "$ENV{SITE}/_site" : $ENV{SITE};
my $files_app = Plack::App::File->new(root => "$ENV{SITE}/uploads")->to_app;
my $dir_app = Plack::App::DirectoryIndex->new(root => "$www")->to_app;
my $blocks_app = Plack::App::DirectoryIndex->new(root => "$ENV{HOME}/.ipfs/blocks")->to_app;
my $psgi_app = Plack::App::PSGIBin->new(root => "$ENV{SITE}/psgi")->to_app;
# /app/* APIs
#y $signup_app = Plack::Util::Load::load_app("app/signup.psgi");
my $login_app = Plack::Util::Load::load_app("app/login.psgi");
#my $codes_app = Plack::Util::Load::load_app("app/codes.psgi");
#my $json_app = Plack::Util::Load::load_app("app/json.psgi"); # jsonGET, jsonPUT
my $ipfs_app = Plack::Util::Load::load_app("app/ipfs.psgi");


# misc. APIs
my $mnemo_app = Plack::Util::Load::load_app("psgi/mnemonic.psgi");
my $qrcode_app = Plack::Util::Load::load_app("psgi/qrcode.psgi");
my $alive_app = Plack::Util::Load::load_app("psgi/alive.psgi");
my $echo_app = Plack::Util::Load::load_app("psgi/echo.psgi");
my $cat_app = Plack::Util::Load::load_app("psgi/cat.psgi");

# --------- ROUTES -------------------------------------
my $urlmap = Plack::App::URLMap->new;
# note /app APIs are not functional due to nginx config
#$urlmap->map("/app/signup" => $signup_app);
#$urlmap->map("/app/login" => $login_app);
#$urlmap->map("/app/codes" => $codes_app);
#$urlmap->map("/app/secret" => $secret_app);
#$urlmap->map("/app/qrcode" => $qrcode_app);

$urlmap->map("/api/v0/key/mnemonic" => $mnemo_app);
#$urlmap->map("/pku" => $pku_app);
#$urlmap->map("/cas" => $cas_app);

#$urlmap->map("/api/v0/signup" => $signup_app);
$urlmap->map("/api/v0/login" => $login_app);
#$urlmap->map("/api/v0/codes" => $codes_app);
$urlmap->map("/api/v0/qrcode" => $qrcode_app);
$urlmap->map("/api/v0/ipfs" => $ipfs_app);
#$urlmap->map("/api/v0/json" => $json_app);
$urlmap->map("/api/v0/echo" => $echo_app);

$urlmap->map("/api/v0/alive" => $alive_app);
$urlmap->map("/api/v0/cat" => $cat_app);

$urlmap->map("/api/v0" => $psgi_app); # catch all api
$urlmap->map("/psgi" => $psgi_app);
$urlmap->map("/files" => $files_app);
$urlmap->map("/ipfs/blocks" => $blocks_app);
$urlmap->map("/" => $dir_app);
# ------------------------------------------------------
## misc. routing 
#$urlmap->map("http://bar.example.com/" => $dir_app);
# ------------------------------------------------------
