#!/usr/bin/env perl
#garden/get-solo-challenge/leek_id/token

use warnings;
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON::Parse 'parse_json';

my $VERSION = '1.0';
my $wait_time = 15;

my $URL = 'http://leekwars.com/api';

my ($login, $password);

GetOptions (
    'login:s'     => \$login,
    'password:s'  => \$password,
  );

print "Lancement des combats pour : $login.\n";

my $ua = LWP::UserAgent->new(
  'agent' => "LKFight $login $VERSION ($^O)",
  cookie_jar => HTTP::Cookies->new(
      file           => "/tmp/$0_$login.cookie",
      autosave       => 1,
      ignore_discard => 1,
    )
  );

# Login
my $res = $ua->post ( "$URL/farmer/login",
    Content       => [
        login     => $login,
        password  => $password,
        keep      => 'on',
      ],
  );

if ( ! $res->is_success) {
  die 'Login échoué : '.$res->status_line."\n";
}


my $fights;
my $max_count = 90*3;
my $combat = 30;
my $count = 0;
my $done = 0;
COMBAT: while ($combat > 0 && $count < $max_count) {

  $res = $ua->post("$URL/garden/get", Content => [token => '$']);
  die( 'Récupération du jardin échouée : '.$res->status_line."\n" ) unless ( $res->is_success );
  my $garden = parse_json( $res->decoded_content )->{'garden'};

  # Le nombre de combats possibles, et abondon si aucun possible.
  if ( defined $garden->{'solo_fights'} ) {
    $combat = $garden->{'solo_fights'};
    last COMBAT if $combat < 1;
  }

  # On liste nos poireaux.
  foreach my $leek( keys %{ $garden->{'solo_enemies'} } ) {
    # Tant qu’à faire, on s’inscrit au tournoi journalier.
    $res = $ua->post("$URL/leek/register-tournament/", Content => [leek_id => $leek, token => '$']);

    # Liste les ennemies possibles.
    my $enemy = $garden->{'solo_enemies'}->{ $leek }->[rand @{ $garden->{'solo_enemies'}->{ $leek } }];
    $res = $ua->post(
        "$URL/garden/start-solo-fight/",
        Content => [
            leek_id => $leek,
            target_id => $enemy->{'id'},
            token => '$' ]
      );
    die( 'Lancement du combat échoué : '.$res->status_line."\n" ) unless ( $res->is_success );
    my $response = parse_json( $res->decoded_content );

    # Ça a saigné !
    if ( $response->{'success'} == 1 ) {
      $combat--;
      $done++;
      print "http://leekwars.com/fight/$response->{fight}\t";
      print "http://leekwars.com/report/$response->{fight}\n";
      sleep( $wait_time );

    } else {
      print "Échec d’un combat.\n";
      print Dumper($response),"\n";
    }
    $count++;
  }
}

print "$count combats lancés, $done effectués, et $combat restants.\n";





__END__



