#!/usr/bin/perl
use strict;
use Nagios::Config;
use Nagios::Object;
use Getopt::Std;
use YAML;
use Pod::Usage;

our $opt_c;
our $opt_m;
our $opt_g;
our $opt_h;

getopt('h:c:m:g');

pod2usage(-verbose => 2) if ($opt_h);

pod2usage("Please specify nagios.cfg file (-c etc/nagios.cfg).")
	unless defined($opt_c);
pod2usage("Please specify a mode (-m h|s)")
	unless defined($opt_m);
pod2usage("Please specify a group membership pattern to search for! (-g)")
	unless defined($opt_g);

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

__END__

=head1 NAME

nagios_group_check.pl - Parse Nagios configuration an show Hosts/Services which are not assignet to a group named by a pattern. 

=head1 SYNOPSIS

perl -X nagios_group_check.pl -c [nagios.cfg] -m [mode] -g [pattern]

=head1 OPTIONS

=over 10

=item B<-c>

Path to nagios.cfg

=item B<-m>

h = hosts
s = services

=item B<-g>

Group pattern (regex)

=back

=head1 DESCRIPTION 

Sometimes it is neccessary to easily get a list of all hosts or all services
which are B<not yet member of a special group>. This is where this script comes
handy. 
It takes the nagios.cfg file, parses it (with all referenced config files), 
and builds up the whole configuration within a perl data structure. 
Dependending on the mode (host/service) it loops over all hosts/services and 
finds out if each of them if member in a group which matches the pattern 
given with the group pattern option. If not, the object will be printed out. 
As a result, you get a "check list" of all objects which are not yet assigned
properly. 

=head1 CAVEATS

Only tested with nagios configuration files generated by op5 monitor. Works
_perhaps_ also with common nagios files. 

=head1 EXAMPLES

To suppress warnings, call the script with 'perl -X'. 

perl -X nagios_group_check.pl -c /etc/nagios/nagios.cfg  -m s -g 'sg_operation_class_A'

perl -X nagios_group_check.pl -c /etc/nagios/nagios.cfg  -m h -g 'hg_operation_class_A'

=head1 AVAILABILITY

https://github.com/simonmeggle/helferlein/tree/master/nagios_group_check

=head1 AUTHOR

9/2012, Simon Meggle <simon.meggle@consol.de>
