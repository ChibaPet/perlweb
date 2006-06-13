package Combust::RoseDB;

use strict;
use Combust::Config;
use DBI;
use base 'Rose::DB';

BEGIN {
  __PACKAGE__->use_private_registry;

  # Cause DBI to use cached connections. Apache::DBI also sets this
  # and we don't want to override that
  $DBI::connect_via = "connect_cached" if $DBI::connect_via eq 'connect';
  
  my %dbs = Combust::Config::_setup_dbs();
  
  (values %dbs)[0]->{default} = 1 if 1 == keys %dbs;
  
  while (my($db_name, $db_cfg) = each %dbs) {
    $db_cfg = $dbs{$db_cfg->{alias}} if $db_cfg->{alias};

    my $dsn = $db_cfg->{data_source}
      or do { require Data::Dumper; die Data::Dumper::Dumper($db_cfg) };
  
    my ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) = DBI->parse_dsn($dsn)
        or die "Can't parse DBI DSN '$dsn'";
  
    my %opt = (
      domain   => $db_cfg->{domain} || 'combust',
      type     => $db_name,
      driver   => $driver,
      dsn      => $dsn,
      username => $db_cfg->{user},
      password => $db_cfg->{password},
    );
    $opt{server_time_zone} = $db_cfg->{time_zone} if $db_cfg->{time_zone};
    
    __PACKAGE__->register_db(%opt);
    
    if ($db_cfg->{default}) {
      __PACKAGE__->default_type($opt{type});
      __PACKAGE__->default_domain($opt{domain});
    }
  }
}

my %rdb;

sub new {
  my($class) = shift;

  @_ = (type => $_[0])  if(@_ == 1);

  my %args = @_;

  my $domain = 
    exists $args{'domain'} ? $args{'domain'} : $class->default_domain;

  my $type = 
    exists $args{'type'} ? $args{'type'} : $class->default_type;

  my $db = $rdb{"$domain.$type"};
  
  unless ($db) {
    $db = $rdb{"$domain.$type"} = $class->SUPER::new(@_);
    $db->retain_dbh; # Prevent Rose::DB from disconnecting
  }
  
  $db;
}

1;
