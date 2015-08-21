#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON::Parse 'parse_json';
# use Data::Dumper; # Envie de debug ? (:

my $VERSION = '1.1';
my $wait_time = 3;
my $URL = 'http://leekwars.com';
my $API_URL = "$URL/api";

my ($login, $password);

GetOptions (
    'login:s'     => \$login,
    'password:s'  => \$password,
  );


my $ua = LWP::UserAgent->new(
  'agent' => "LKFight $login $VERSION ($^O)",
  cookie_jar => HTTP::Cookies->new(
      file           => "/tmp/$0_$login.cookie",
      autosave       => 1,
      ignore_discard => 1,
    )
  );

# Login
my $res = $ua->post ( "$API_URL/farmer/login",
    Content       => [
        login     => $login,
        password  => $password,
        keep      => 'on',
      ],
  );

if ( ! $res->is_success) {
  die 'Login échoué : '.$res->status_line."\n";
}

sub getGarden {
  my $res = $ua->post("$API_URL/garden/get", Content => [token => '$']);
  die( 'Récupération du jardin échouée : '.$res->status_line."\n" ) unless ( $res->is_success );
  return parse_json( $res->decoded_content )->{'garden'};
}

# Un petit tour dans le potager…
my $garden = getGarden();
my $myLeeks = {};

# On récupère les poireaux, et leurs nombres de combats restants.
if ( $garden->{'leek_fights'} && ! scalar %{$myLeeks} ) {
  $myLeeks = $garden->{'leek_fights'};
} else {
  die('Pas de poireaux… WTF ?!'."\n");
}


# On parcours les poireaux.
foreach my $leek( keys %{$myLeeks} ) {
  print STDOUT "Combat du poireau $leek pour $login.\n";

  # Tant que le poireau courant a des combats possibles, on bastonne.
  for (my $i = $myLeeks->{$leek}; $i > 0; $i-- ) {

    # Comme nous sommes des gens civilisés, on évite de pourrir le serveur.
    sleep( $wait_time );

    # On se balade de nouveau dans le potager, des fois qu’il y aurait une carotte.
    $garden = getGarden();

    # On aggresse un poireau au hasard.
    my $enemy = $garden->{'solo_enemies'}->{ $leek }->[rand @{ $garden->{'solo_enemies'}->{ $leek } }];
    $res = $ua->post(
        "$API_URL/garden/start-solo-fight/",
        Content => [
            leek_id => $leek,
            target_id => $enemy->{'id'},
            token => '$' ]
      );
    die( 'Lancement du combat échoué : '.$res->status_line."\n" ) unless ( $res->is_success );
    my $response = parse_json( $res->decoded_content );

    # Ça a saigné !
    if ( $response->{'success'} == 1 ) {
      print "$URL/fight/$response->{fight}\t$URL/report/$response->{fight}\n";
    } else {
      print STDERR "Échec du combat contre « $enemy ».";
    }
  }
}


__END__
