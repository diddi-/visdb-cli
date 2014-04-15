#!/usr/bin/env perl

use warnings;
use strict;
use lib '/home/diddi/git/libvis-perl/lib/';
use Net::VIS;
use Getopt::Long;

my $db_host = "localhost";
my $db_user = "visdb";
my $db_pass = "vis_password";
my $db_name = "visdb";

# Search filters
my $domain_serial = undef;
my $vlan_tag = undef;
my $domain_name = undef;
my $vlan_name = undef;
my $type_name = undef;
my $name = undef;
my $description = "";
my $vlan_low = undef;
my $vlan_high = undef;

# Action options
my $s_list_domains = 0;
my $s_list_allocations = 0;
my $s_list_vlan_types = 0;
my $s_alloc_vlan = 0;
my $s_free_vlan = 0;
my $s_help = 0;
my $s_add_type = 0;
my $s_del_type = 0;
my $s_add_domain = 0;
my $s_del_domain = 0;

my $visdb = Net::VIS->new( dbhost => $db_host, dbuser => $db_user, dbpass => $db_pass, dbname => $db_name );

sub list_domains {
  print "\n";
  my $domains = $visdb->get_domain({domain_serial => $domain_serial, domain_name => $domain_name});
  my $format = "%-10s %-15s %s";

  printf($format."\n", "Domain ID", "Domain Name", "Domain Description");
  print "="x70;
  print "\n";

  foreach my $domain (@{$domains}){
    printf($format."\n", $domain->{'domain_serial'}, $domain->{'domain_name'}, $domain->{'domain_description'});
  }
  print "\n";
}

sub list_allocations {
  print "\n";
  my $allocations = $visdb->get_vlan_alloc({domain_serial => $domain_serial, domain_name => $domain_name, vlan_tag => $vlan_tag, vlan_name => $vlan_name});
  my $format = "%-20s %-15s %-10s %s";

  my $output = sprintf($format, "Domain(ID)", "Name", "Tag", "Description");
  print $output."\n";
  print "="x70;
  print "\n";
  foreach my $alloc (@{$allocations}) {
    printf($format."\n", $alloc->{'domain_name'}."(".$alloc->{'domain_serial'}.")", $alloc->{'vlan_name'}, $alloc->{'vlan_tag'}, $alloc->{'vlan_description'});
  }
  print "\n";
}

sub list_vlan_types {
  print "\n";
  my $types = $visdb->get_vlan_type({domain_serial => $domain_serial, domain_name => $domain_name, name => $type_name});
  my $format = "%-15s %-15s %-10s %-10s %s";

  printf($format."\n", "Domain(ID)", "Name", "VLAN Low", "VLAN High", "Description");
  print "="x70;
  print "\n";

  foreach my $type (@{$types}) {
    printf($format."\n", $type->{'domain_name'}."(".$type->{'domain_serial'}.")", $type->{'name'}, $type->{'vlan_low'}, $type->{'vlan_high'}, $type->{'description'});
  }
  print "\n";
}

sub alloc_vlan {
  my $tag = 0;

  if(not defined $domain_name) {
    print "Missing argument --domain\n";
    return -1;
  }
  if(not defined $type_name) {
    print "Missing argument --type\n";
    return -1;
  }
  if(not defined $name) {
    print "Missing argument --name\n";
    return -1;
  }

  my $domains = $visdb->get_domain({domain_name => $domain_name, domain_serial => $domain_serial});
  my $type = $visdb->get_vlan_type({domain_name => $domain_name, name=>$type_name});

  if( @{$domains} <= 0 ) {
    print "'$domain_name': No such domain name\n";
    return -2;
  }
  if( @{$domains} > 1 and not defined $domain_serial) {
    print "'$domain_name': Domain is not unique, please use --domain-id\n";
    list_domains();
    return -2;
  }
  if( @{$type} <= 0 ) {
    print "'$type_name': No such VLAN type\n";
    return -2;
  }

  if(defined $vlan_tag and $vlan_tag > 0) {
    $tag = $vlan_tag;
  }else{
    $tag = $visdb->get_next_tag({domain_id => @{$domains}[0]->{'id'}, type_id => @{$type}[0]->{'id'}});
    if(not defined $tag or $tag <= 0) {
      print "Unable to allocate a new VLAN tag of type $type_name in $domain_name\n";
      return -3;
    }
  }

  print "Allocating VLAN $tag...\n";
  $visdb->vlan_alloc({domain_id => @{$domains}[0]->{'id'}, type_id => @{$type}[0]->{'id'}, vlan_tag => $tag, vlan_name => $name, vlan_description => $description});
  return 0;
}

sub free_vlan {

  if(not defined $domain_name) {
    print "Missing argument --domain\n";
    return -1;
  }
  if(not defined $vlan_tag) {
    print "Missing argument --tag\n";
    return -1;
  }

  my $domains = $visdb->get_domain({domain_name => $domain_name, domain_serial => $domain_serial});
  if( @{$domains} <= 0 ) {
    print "'$domain_name': No such domain name\n";
    return -2;
  }
  if( @{$domains} > 1 and not defined $domain_serial) {
    print "'$domain_name': Domain is not unique, please use --domain-id\n";
    list_domains();
    return -2;
  }

  print "Removing VLAN $vlan_tag from domain $domain_name(".@{$domains}[0]->{'domain_serial'}.")...\n";
  $visdb->vlan_alloc_free({domain_id => @{$domains}[0]->{'id'}, vlan_tag => $vlan_tag});

  return 0;
}

sub add_type {

  if(not defined $domain_name) {
    print "Missing argument --domain\n";
    return -1;
  }
  if(not defined $name) {
    print "Missing argument --name\n";
    return -1;
  }
  if(not defined $vlan_low) {
    print "Missing argument --vlan-low\n";
    return -1;
  }
  if(not defined $vlan_high) {
    print "Missing argument --vlan-high\n";
    return -1;
  }

  my $domains = $visdb->get_domain({domain_name => $domain_name, domain_serial => $domain_serial});
  if( @{$domains} <= 0 ) {
    print "'$domain_name': No such domain name\n";
    return -2;
  }
  if( @{$domains} > 1 and not defined $domain_serial) {
    print "'$domain_name': Domain is not unique, please use --domain-id\n";
    list_domains();
    return -2;
  }

  print "Adding VLAN type $name, tag range $vlan_low -> $vlan_high\n";
  $visdb->create_vlan_type({domain_id => @{$domains}[0]->{'id'}, name => $name, vlan_low => $vlan_low, vlan_high => $vlan_high, description => $description});

  return 0;
}

sub delete_type {

  if(not defined $domain_name) {
    print "Missing argument --domain\n";
    return -1;
  }
  if(not defined $name) {
    print "Missing argument --name\n";
    return -1;
  }

  my $domains = $visdb->get_domain({domain_name => $domain_name, domain_serial => $domain_serial});
  if( @{$domains} <= 0 ) {
    print "'$domain_name': No such domain name\n";
    return -2;
  }
  if( @{$domains} > 1 and not defined $domain_serial) {
    print "'$domain_name': Domain is not unique, please use --domain-id\n";
    list_domains();
    return -2;
  }

  my $vlan_type = $visdb->get_vlan_type({id => @{$domains}[0]->{'id'}, name => $name});
  if(@{$vlan_type} <= 0) {
    print "Could not find matching VLAN type...\n";
    return -3;
  }
  print "Removing VLAN type $name...\n";
  $visdb->delete_vlan_type(@{$vlan_type}[0]->{'id'});

  return 0;
}

sub add_domain {

  if(not defined $domain_serial) {
    print "Missing argument --domain-id\n";
    return -1;
  }
  if(not defined $name) {
    print "Missing argument --name\n";
    return -1;
  }

  print "Creating domain $name...\n";
  $visdb->create_domain({domain_serial => $domain_serial, domain_name => $name, domain_description => $description});

  return 0;
}

sub del_domain {

  if(not defined $domain_serial) {
    print "Missing argument --domain-id\n";
    return -1;
  }

  my $vlans = $visdb->get_vlan_alloc({domain_serial => $domain_serial});
  my $types = $visdb->get_vlan_type({domain_serial => $domain_serial});

  if(@{$vlans} > 0 or @{$types} > 0) {
    print "There are ".@{$vlans}." VLANs associated with this domain.\n";
    print "There are ".@{$types}." VLAN types associated with this domain.\n";
    print "Would you like to delete those as well (Y/N)? ";
    chomp(my $input = <STDIN>);
    if($input =~ m/^y/i) {
      foreach my $vlan (@{$vlans}) {
        print "Removing VLAN ".$vlan->{'vlan_name'}." (tag ".$vlan->{'vlan_tag'}.")...\n";
        $visdb->vlan_alloc_free({domain_id => $vlan->{'domain_id'}, vlan_tag => $vlan->{'vlan_tag'}});
      }
      foreach my $type (@{$types}) {
        print "Removing VLAN type ".$type->{'name'}."...\n";
        $visdb->delete_vlan_type($type->{'id'});
      }
    }else{
      print "Won't delete domain leaving orphan objects!\n";
      return -3;
    }
  }

  print "Removing domain ID $domain_serial...\n";
  $visdb->delete_domain($domain_serial);

  return 0;
}

sub help {

  my $format = "%-20s %s";
  if($s_list_domains) {
    print("visdb.pl --list-domains [--domain <name>]\n\n");
    printf($format."\n", "--domain <name>", "List all domains with <name>");
  }
  elsif($s_list_allocations) {
    print("visdb.pl --list-allocations [--domain <name> --tag <tag>]\n\n");
    printf($format."\n", "--domain <name>", "List all allocations within domain <name>");
    printf($format."\n", "--tag <tag>", "List all allocations with VLAN tag <tag>");
  }
  elsif($s_list_vlan_types) {
    print("visdb.pl --list-types [--domain <name>]\n\n");
    printf($format."\n", "--domain <name>", "List all VLAN types within domain <name>");
  }
  elsif($s_free_vlan) {
    print("visdb.pl --free --domain <name> --tag <tag> [--domain-id <id>]\n\n");
    printf($format."\n", "--domain <name>", "Free a VLAN allocation within domain <name>");
    printf($format."\n", "--tag <tag>", "Free a VLAN with VLAN tag <tag>");
    printf($format."\n", "--domain-id <id>", "Free using domain-id if domain name is not unique");
  }
  elsif($s_alloc_vlan) {
    print("visdb.pl --alloc --domain <name> --name <name> --type <type> [--domain-id <id> --description <description]\n\n");
    printf($format."\n", "--domain <name>", "Allocate a VLAN within domain <name>");
    printf($format."\n", "--name <name>", "Allocate a VLAN with VLAN name <name>");
    printf($format."\n", "--type <type>", "Allocate a VLAN of type <type>");
    printf($format."\n", "--domain-id <id>", "Allocate a VLAN within domain-id if domain <name> is not unique");
    printf($format."\n", "--description <description>", "Allocate a VLAN with description <description>");
  }
  elsif($s_add_type){
    print("visdb.pl --create-type --domain <name> --name <name> --vlan-low <int> --vlan-high <int> [--description <description>]\n\n");
    printf($format."\n", "--domain <name>", "Create a VLAN type in domain <name>");
    printf($format."\n", "--name <name>", "Create a VLAN type using name <name>");
    printf($format."\n", "--vlan-low <int>", "Set the start-tag for this VLAN type range");
    printf($format."\n", "--vlan-high <int>", "Set the end-tag for this VLAN type range");
    printf($format."\n", "--description <description>", "Set an optional description for this VLAN type");
  }
  else {
    print("visdb.pl <action>\n\n");
    printf($format."\n", "--list-domains", "List all L2 domains");
    printf($format."\n", "--list-alloc", "List all VLAN allocations");
    printf($format."\n", "--list-types", "List all VLAN types");
    printf($format."\n", "--create-type", "Create a new VLAN type");
    printf($format."\n", "--create-domain", "Create a new L2 domain");
    printf($format."\n", "--alloc", "Allocate a new VLAN");
    printf($format."\n", "--delete-type", "Delete a VLAN type");
    printf($format."\n", "--delete-domain", "Delete a L2 domain");
    printf($format."\n", "--free", "Free a VLAN allocation");
    print "Use --help <action> to see further help for the specific action\n";
  }

  print "\n";
  return 0;
}
sub main {

  GetOptions(
    'list-domains' => \$s_list_domains,
    'list-allocations|list-alloc' => \$s_list_allocations,
    'list-types' => \$s_list_vlan_types,
    'domain=s' => \$domain_name,
    'domain-id=i' => \$domain_serial,
    'type=s' => \$type_name,
    'name=s' => \$name,
    'vlan-alloc|alloc' => \$s_alloc_vlan,
    'description=s' => \$description,
    'free' => \$s_free_vlan,
    'vlan_tag|tag=i' => \$vlan_tag,
    'help' => \$s_help,
    'add-type|create-type' => \$s_add_type,
    'delete-type|remove-type' => \$s_del_type,
    'add-domain|create-domain' => \$s_add_domain,
    'delete-domain|remove-domain' => \$s_del_domain,
    'vlan-low|low=i' => \$vlan_low,
    'vlan-high|high=i' => \$vlan_high,
  );

  if($s_help) {
    help();
    return 0;
  }

  if($s_list_allocations) {
    list_allocations();
  }
  if($s_list_vlan_types) {
    list_vlan_types();
  }
  if($s_list_domains) {
    list_domains();
  }
  if($s_alloc_vlan) {
    alloc_vlan();
  }
  if($s_free_vlan) {
    free_vlan();
  }
  if($s_add_type) {
    add_type();
  }
  if($s_del_type) {
    delete_type();
  }
  if($s_add_domain) {
    add_domain();
  }
  if($s_del_domain) {
    del_domain();
  }

  return 0;
}
main();
