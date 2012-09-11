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
$cfg->register_objects();
if ($opt_m eq "s") {
	my $servicegroups_ref = $cfg->list_servicegroups;
        foreach my $service_ref ($cfg->list_services) {
                if ($service_ref->register eq 1) {
                        my @h;
			my $res = 0; 
                        if (defined($service_ref->host_name)) {
                                push (@h, map {$_->host_name} @{$service_ref->host_name} );
                        }   
                        if (defined($service_ref->hostgroup_name)) {
                                push (@h, map {$_->hostgroup_name} @{$service_ref->hostgroup_name} );
                        }  
			if (defined($service_ref->servicegroups)) { 
				foreach my $sg_ref (@{$service_ref->servicegroups}) {
					if ($sg_ref->servicegroup_name =~ m/$pattern/) {
						$res = 1;
						last;
					}
	                        	foreach my $sgs_ref (@$servicegroups_ref) {
						$res = servicegroup_match($sgs_ref,$sg_ref->servicegroup_name,0);
						last if $res; 
					}
				}
			}
                        print join(", ", @h) . ": '" . $service_ref->service_description . "'\n" 
				if (! $res); 
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

sub servicegroup_match {
	# $A = Servicegroup is member
	# $B = Group matches pattern
	my ($sg_ref,$servicegroup_name,$B) = @_;
	my $A = 0;
	# Flag setzen, wenn Gruppe dem gesuchten Pattern entspricht
	if (($sg_ref->servicegroup_name =~ m/$pattern/)) {
		$B = 1; 	
	}
	# Handelt es sich um die Gruppe, in der der aktuelle Service ist? 
	if ($sg_ref->servicegroup_name eq $servicegroup_name) {
		$A = 1; 
	}
	if (defined($sg_ref->servicegroup_members)) {
		($A = 1) if (grep /1/, map { servicegroup_match($_,$servicegroup_name,$B)} @{$sg_ref->servicegroup_members});
	};
	my $ret = ($B && $A) ;
	return $ret;
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

