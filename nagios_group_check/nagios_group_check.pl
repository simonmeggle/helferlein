#!/usr/bin/perl
#use strict;
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
        foreach my $host ($cfg->list_hosts) {
                if ($host->register eq 1) {
                my $found = 0;
        #               print "Processing " . $s->service_description . "...\n";
                        if (defined($host->hostgroups)) {
                                foreach my $hg (@{$host->hostgroups}) {
                                        if ($hg->{hostgroup_name} =~ m/$pattern/) {$found = 1;} 
                                }   
                        }   
                        print $host->host_name . "\n" if ($found == 0); 
                }   
        }   
} else {
        die "Unknown mode $opt_m (h=host, s=service)!";
}

