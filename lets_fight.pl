#!/usr/bin/env perl
#garden/get-solo-challenge/leek_id/token

use warnings;
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON::Parse 'parse_json';

my $VERSION = '1.0';

my $URL = 'http://leekwars.com/api';

my ($login, $password, $cook);
my $command = 'list';

GetOptions (
    'login:s'     => \$login,
    'password:s'  => \$password,
  );
$command = lc $command;

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

  # Le nombre de combats possibles.
  if ( defined $garden->{'solo_fights'} ) {
    $combat = $garden->{'solo_fights'};
    last COMBAT if $combat < 1;
  }
  #print Dumper $garden;
  #print "Il reste $combat combats.\n";


  # On liste nos poireaux.
  GET_FIGHT: foreach my $leek( keys %{ $garden->{'solo_enemies'} } ) {
    # Tant qu’à faire, on s’inscrit au tournoi journalier.
    #farmer/register-tournament
    $res = $ua->post("$URL/leek/register-tournament/", Content => [leek_id => $leek, token => '$']);

    # Puis leur ennemies possibles.
    my $enemy = $garden->{'solo_enemies'}->{ $leek }->[rand @{ $garden->{'solo_enemies'}->{ $leek } }];

    #print Dumper( $enemy );
    $res = $ua->post(
        "$URL/garden/start-solo-fight/",
        Content => [
            leek_id => $leek,
            target_id => $enemy->{'id'},
            token => '$' ]
      );
    die( 'Lancement du combat échoué : '.$res->status_line."\n" ) unless ( $res->is_success );
    #print Dumper parse_json( $res->decoded_content );
    my $response = parse_json( $res->decoded_content );

    if ( $response->{'success'} == 1 ) {
      $combat--;
      $done++;
      print "http://leekwars.com/fight/$response->{fight}\t";
      print "http://leekwars.com/report/$response->{fight}\n";
      sleep( 3 );

      # fight/get/fight_id
      #$res = $ua->post(
      #    "$URL/fight/get",
      #    Content => [
      #        fight_id => $response->{fight},
      #        token => '$' ]
      #  );
      #die( 'Récupération du combat échouée : '.$res->status_line."\n" ) unless ( $res->is_success );
      #my $fight = parse_json( $res->decoded_content );
      #print Dumper( $fight );

    } else {
      print "Échec d’un combat.\n";
      print Dumper($response),"\n";
      #$count++;
      #last GET_FIGHT;
    }
    $count++;
  }

  FIGHT: foreach my $leek( keys %{$fights} ) {

  }

  $count++;
}

print "$count combats lancés, $done effectués, et $combat restants.\n";





__END__



