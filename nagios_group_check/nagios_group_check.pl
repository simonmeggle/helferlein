#!/usr/bin/perl
use strict;
use Nagios::Config;
use Nagios::Object;
use Getopt::Std;

use YAML;
our $opt_c;
our $opt_m;
our $opt_g;


getopt('c:m:g');
die "Please specify nagios.cfg file (-c etc/nagios.cfg)."
        if (!$opt_c);

die "Please specify a mode (-m h|s)"
        if (!$opt_m);

die "Please specify a group membership pattern to search for! (-g)"
        if (!$opt_g);


my $pattern = $opt_g;

my $cfg = Nagios::Config->new(
        Filename => $opt_c,
        regexp_matching => 1
);

die "Unable to parse!"
        if (!$cfg);
if ($opt_m eq "s") {
	my $sgroups = $cfg->list_servicegroups;
        foreach my $s ($cfg->list_services) {
                if ($s->register eq 1) {
                        my $found = 0;
        #               print "Processing " . $s->service_description . "...\n";
                        my @h; 
                        if (defined($s->host_name)) {
                                push (@h, map {$_->host_name} @{$s->host_name} );
                        }   
                        if (defined($s->hostgroup_name)) {
                                push (@h, map {$_->hostgroup_name} @{$s->hostgroup_name} );
                        }   
                        if (defined($s->servicegroups)) {
                                foreach my $sg (@{$s->servicegroups}) {
                                        if ($sg->{servicegroup_name} =~ m/$pattern/) {$found = 1;} 
                                }   
                                next;
                        }   
                        print join(", ", @h) . ": '" . $s->service_description . "'\n" if ($found == 0); 
                }   
        }   
} elsif ($opt_m eq "h") {
	my $hostgroups_ref = $cfg->list_hostgroups;
        foreach my $host_ref ($cfg->list_hosts) {
                if ($host_ref->register eq 1) {
			my $res = 0;
			foreach (@$hostgroups_ref) {
				$res = host_is_member_of_group($_,$host_ref->host_name,0);
				last if $res;
			}
			print $host_ref->host_name . "\n" 
				if (! $res);
                }   
        }   
} else {
        die "Unknown mode $opt_m (h=host, s=service)!";
}
	
sub host_is_member_of_group {
	# $A = Host is member
	# $B = Group matches pattern

	my ($hg_ref,$hostname,$B) = @_;
	my $A = 0;
	if (($hg_ref->hostgroup_name =~ m/$pattern/)) {
		$B = 1; 	
	}
	if (defined($hg_ref->members)) {
		if (grep /$hostname/, map {$_->host_name} @{$hg_ref->members}) {
			$A = 1; 
		}
	}
	if (defined($hg_ref->hostgroup_members)) {
		($A = 1) if (grep /1/, map { host_is_member_of_group($_,$hostname,$B)} @{$hg_ref->hostgroup_members});
	};
	
	my $ret = ($B && $A) ;
	return $ret;
}

