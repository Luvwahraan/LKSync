#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Cookies;
use JSON::Parse 'parse_json';

my $VERSION = '1.0';

my $URL = 'http://leekwars.com/api';

my ($login, $password, $rep);
my $command = 'list';

GetOptions (
    'login:s'     => \$login,
    'password:s'  => \$password,
    'directory=s' => \$rep,
    'command=s'   => \$command,
  );
$command = lc $command;


sub listAI;
sub pushAI;
sub pullAI;



my $ua = LWP::UserAgent->new(
  'agent' => "LKSync $VERSION ($^O)",# );
  cookie_jar => HTTP::Cookies->new(
      file           => "/tmp/$0.cookie",
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


# List all AI
$res = $ua->post("$URL/ai/get-farmer-ais", Content => [token => '$']);
die( 'Récupération des IA échouée : '.$res->status_line."\n" ) unless ( $res->is_success );
my $AI = parse_json( $res->decoded_content );


#use Data::Dumper;
#print Dumper($AI);


if ( $command eq 'push' ) {
  print "push\n";
  pushAI();
} elsif ( $command eq 'pull' ) {
  pullAI();
} elsif ( $command eq 'list' ) {
  listAI($AI);
} else {
  die "Commande '$command' invalide.\n";
}


sub pushAI {
  die("Option --directory absente ; abandon.\n") unless ( defined $rep && ! $rep eq '' );

  # On organise la liste des IA distantes, afin de pouvoir chercher dedans.
  my $ai_hash;
  foreach my $file( @{$AI->{'ais'}}  ) {
    $ai_hash->{$file->{id}} = $file->{name};
  }

  #use Data::Dumper;
  #print Dumper($ai_hash);

  my $dir = "$rep/by-id";
  opendir(my $DH, $dir) or die("Impossible de lire $rep\n");
  my @symlinks = grep { -l "$dir/$_" } readdir( $DH );

  foreach my $id(@symlinks) {
    my $filename = "$dir/$id";
    my $name = readlink $filename or die "Erreur de symlink '$filename' : $!\n";
    $id   =~ s|(.*)\.js|$1|i;
    $name =~  s|.*/(.*)\.js$|$1|i;

    open(FH, $filename) or die("Impossible de lire $name ($id).\n");
    my $code = do { local $/; <FH> };

    # Si le nom est différent, on renome le fichier distant.
    unless ( $ai_hash->{$id} eq $name ) {
      print "On renome le fichier distant.\n";
      $res = $ua->post("$URL/ai/rename/", Content => [ai_id => $id, new_name => $name, token => '$']);
      die( 'Opération échouée : '.$res->status_line."\n" ) unless ( $res->is_success );
    }

    print "Envoie de $name ($id)";
    $res = $ua->post("$URL/ai/save/", Content => [ai_id => $id, code => $code, token => '$']);
    die( ' échoué : '.$res->status_line."\n" ) unless ( $res->is_success );
    print "\n";

  }

  closedir $DH;
}


sub pullAI {
  die("Option --directory absente ; abandon.\n") unless ( defined $rep && ! $rep eq '' );
  #$rep =~ s/ /\ /g;

  foreach my $file( @{$AI->{'ais'}}  ) {
    my $id = $file->{id};
    my $name = $file->{name};
    print "Récupération de l’IA $name ($id).\n";

    $res = $ua->post("$URL/ai/get/", Content => [ai_id => $id, token => '$']);
    die( 'Récupération échouée : '.$res->status_line."\n" ) unless ( $res->is_success );

    my $content = parse_json( $res->decoded_content )->{ai}->{code};
    $content =~ s/\t/  /g;

    # On vérifie les répertoires.
    die("$rep n’existe pas.\n") unless( -d "$rep");
    foreach my $d(('by-name','by-id')) {
      unless ( -d "$rep/$d" ) {
        print "Création de $rep/$d";
        mkdir "$rep/$d" or die(" impossible : $!\n");
        print ".\n";
      }
    }

    my $file = "$rep/by-name/$name.js";
    my $idfile = "$rep/by-id/$id.js";

    # On met les données dans le bon fichier, puis on créer un lien symbolique vers
    # ce dernier, pour l’avoir par son id.
    open(FH, ">$file") or die("Impossible d’ouvrir '$file'\n");
    binmode(FH, ":utf8");
    print FH $content;
    close FH;

    symlink( $file, $idfile ) unless ( -l "$idfile");
  }
}



sub pullNewAI {
  die("Option --directory absente ; abandon.\n") unless ( defined $rep && ! $rep eq '' );
  #$rep =~ s/ /\ /g;

  foreach my $file( @{$AI->{'ais'}}  ) {
    my $id = $file->{id};
    my $name = $file->{name};
    my $filename = "$rep/by-name/$name.js";
    my $idfile = "$rep/by-id/$id.js";

    # On passe au suivant si le fichier existe.
    if ( -f $idfile ) {
      next;
    }

    print "Récupération de l’IA $name ($id).\n";

    $res = $ua->post("$URL/ai/get/", Content => [ai_id => $id, token => '$']);
    die( 'Récupération échouée : '.$res->status_line."\n" ) unless ( $res->is_success );

    my $content = parse_json( $res->decoded_content )->{ai}->{code};
    $content =~ s/\t/  /g;

    # On vérifie les répertoires.
    die("$rep n’existe pas.\n") unless( -d "$rep");
    foreach my $d(('by-name','by-id')) {
      unless ( -d "$rep/$d" ) {
        print "Création de $rep/$d";
        mkdir "$rep/$d" or die(" impossible : $!\n");
        print ".\n";
      }
    }

    my $idfile = "$rep/by-id/$id.js";

    # On met les données dans le bon fichier, puis on créer un lien symbolique vers
    # ce dernier, pour l’avoir par son id.
    open(FH, ">$filename") or die("Impossible d’ouvrir '$filename'\n");
    binmode(FH, ":utf8");
    print FH $content;
    close FH;

    symlink( $file, $idfile ) unless ( -l "$idfile");
  }
}


sub listAI {
  printf ( "%20s%10s %3s\n", 'Fichiers', 'ID', 'lvl' );
  foreach my $file( @{$AI->{'ais'}}  ) {
    printf ( "%20s%10s %3s\n", $file->{name}, $file->{id}, $file->{level} );
  }
}


__END__
