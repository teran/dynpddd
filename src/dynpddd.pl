#!/usr/bin/perl

use strict;
use warnings;

use Config::General qw(ParseConfig);
use Crypt::SSLeay;
use LWP::UserAgent;
use Time::Format qw(%time);
use XML::Simple;

my $version = '0.1';
$0 = 'dynpddd';

if(!-f '/etc/dynpddd.conf') {
    die('No config file exists: /etc/dynpddd.conf');
}

my %config = ParseConfig('/etc/dynpddd.conf');

if(!defined $config{'token'} || !defined $config{'domain'} || !defined $config{'subdomain'}) {
    die('One of required options: token, domain, subdomain not defined in config');
}

my %settings = (
    'ttl' => 600,
    'http_timeout' => 20,
    'log' => '/var/log/dynpddd/dynpddd.log',
);

@settings{keys %config} = values %config;

my $ua = LWP::UserAgent->new;
$ua->timeout($settings{'http_timeout'});
$ua->agent("DynPDDd/$version");

reopen_std();

logmsg("Starting DynPDDd $version");

while(1) {
    logmsg('Getting IP address from internet.yandex.ru...');
    my $ip = $ua->get('http://ipv4.internet.yandex.ru/api/v0/ip');
    
    if($ip->code != 200) {
        logmsg('Error obtaining IP address: non-200 return code');
        sleep($settings{'ttl'});
        next;
    }
    
    $ip = $ip->content;
    $ip =~ s/"//g;
    
    if($ip !~ /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/) {
        logmsg('Mailformed reply from internet.yandex.ru');
        sleep($settings{'ttl'});
        next;
    }
    
    logmsg('Fetching domain records...');
    my $domain_list_req = $ua->get(sprintf('https://pddimp.yandex.ru/nsapi/get_domain_records.xml?token=%s&domain=%s', $settings{'token'}, $settings{'domain'}));
    
    if($domain_list_req->code != 200) {
        logmsg('Error obtaining domain records');
        sleep($settings{'ttl'});
        next;
    }
    
    my $domain_list = XMLin($domain_list_req->content);
    my $records = $domain_list->{'domains'}->{'domain'}->{'response'}->{'record'};
    
    foreach my $id(keys %$records) {
        if($records->{$id}->{'subdomain'} eq $settings{'subdomain'} && $records->{$id}->{'domain'} eq $settings{'domain'}) {
            if($records->{$id}->{'content'} eq $ip && $records->{$id}->{'ttl'} eq $settings{'ttl'}) {
                logmsg('Valid data in pdd dns service. No need to be updated.');
            } else {
                logmsg("Updating: ID = $id, DOMAIN = $settings{'domain'}, SUBDOMAIN = $settings{'subdomain'}, CONTENT = $ip, TTL = $settings{'ttl'}");
                my $update_req = $ua->get(sprintf('https://pddimp.yandex.ru/nsapi/edit_a_record.xml?token=%s&domain=%s&subdomain=%s&record_id=%s&ttl=%s&content=%s', $settings{'token'}, $settings{'domain'}, $settings{'subdomain'}, $id, $settings{'ttl'}, $ip));
                if($update_req->code != 200) {
                    logmsg("Update error: $update_req->content");
                } else {
                    logmsg('Successfully updated');
                }
            }
        }
    }
    sleep($settings{'ttl'});
}

sub logmsg {
    my ($message) = @_;
    open(LOG, '>>', $settings{'log'});
    print LOG "$time{'dd.mm.yyyy hh:mm:ss'} $message\n";
    close(LOG);
}

sub reopen_std {   
    open(STDIN,  "+>/dev/null") or die "Can't open STDIN: $!";
    open(STDOUT, "+>&STDIN") or die "Can't open STDOUT: $!";
    open(STDERR, "+>&STDIN") or die "Can't open STDERR: $!";
};

