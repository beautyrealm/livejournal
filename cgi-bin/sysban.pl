#!/usr/bin/perl
#

use strict;
no warnings 'uninitialized';

package LJ;

use LJ::TimeUtil;
use LJ::CaptchaServer;

# <LJFUNC>
# name: LJ::sysban_check
# des: Given a 'what' and 'value', checks to see if a ban exists.
# args: what, value
# des-what: The ban type
# des-value: The value which triggers the ban
# returns: 1 if a ban exists, 0 otherwise
# </LJFUNC>
sub sysban_check {
    my ($what, $value, $opts) = @_;

    # cache if ip ban
    if ($what eq 'ip') {

        my $is_force_use = defined $opts->{'force_use'} ? $opts->{'force_use'} : 0;

        return undef
            if !$is_force_use && $LJ::DISABLED{'sysban'};

warn "SYSBAN: Loading sysban ip list";

        my $now = time();
        my $ip_ban_delay = $LJ::SYSBAN_IP_REFRESH || 120; 

        # check memcache first if not loaded
        unless ($LJ::IP_BANNED_LOADED + $ip_ban_delay > $now) {
            my $memval = LJ::MemCache::get("sysban:ip");
            if ($memval) {
                *LJ::IP_BANNED = $memval;
                $LJ::IP_BANNED_LOADED = $now;
            } else {
                $LJ::IP_BANNED_LOADED = 0;
            }
        }
        
        # is it already cached in memory?
        if ($LJ::IP_BANNED_LOADED) {
            return (defined $LJ::IP_BANNED{$value} &&
                    ($LJ::IP_BANNED{$value} == 0 ||     # forever
                     $LJ::IP_BANNED{$value} > time())); # not-expired
        }

        # set this before the query
        $LJ::IP_BANNED_LOADED = time();

        LJ::sysban_populate(\%LJ::IP_BANNED, "ip")
            or return undef $LJ::IP_BANNED_LOADED;

        # set in memcache
        LJ::MemCache::set("sysban:ip", \%LJ::IP_BANNED, $ip_ban_delay);

        # return value to user
        return $LJ::IP_BANNED{$value};
    
    }
    elsif ($what eq 'ip_captcha'){
        my $now = time();
        my $ip_ban_delay = $LJ::SYSBAN_IP_REFRESH || 120; 

        # check memcache first if not loaded
        unless ($LJ::IP_CAPTCHA_BANNED_LOADED + $ip_ban_delay > $now) {
            my $memval = LJ::MemCache::get("sysban:ip_captcha");
            if ($memval) {
                *LJ::IP_CAPTCHA_BANNED = $memval;
                $LJ::IP_CAPTCHA_BANNED_LOADED = $now;
            } else {
                $LJ::IP_CAPTCAHA_BANNED_LOADED = 0;
            }
            return exists $LJ::IP_CAPTCHA_BANNED{$value} 
                ? $LJ::IP_CAPTCHA_BANNED{$value}
                : undef;
        }
    }
    # cache if uniq ban
    elsif ($what eq 'uniq') {

        # check memcache first if not loaded
        unless ($LJ::UNIQ_BANNED_LOADED) {
            my $memval = LJ::MemCache::get("sysban:uniq");
            if ($memval) {
                *LJ::UNIQ_BANNED = $memval;
                $LJ::UNIQ_BANNED_LOADED++;
            }
        }

        # is it already cached in memory?
        if ($LJ::UNIQ_BANNED_LOADED) {
            return (defined $LJ::UNIQ_BANNED{$value} &&
                    ($LJ::UNIQ_BANNED{$value} == 0 ||     # forever
                     $LJ::UNIQ_BANNED{$value} > time())); # not-expired
        }

        # set this now before the query
        $LJ::UNIQ_BANNED_LOADED++;

        LJ::sysban_populate(\%LJ::UNIQ_BANNED, "uniq")
            or return undef $LJ::UNIQ_BANNED_LOADED;

        # set in memcache
        my $exp = 60*15; # 15 minutes
        LJ::MemCache::set("sysban:uniq", \%LJ::UNIQ_BANNED, $exp);

        # return value to user
        return $LJ::UNIQ_BANNED{$value};
    }
    # cache if contentflag ban
    elsif ($what eq 'contentflag') {

        # check memcache first if not loaded
        unless ($LJ::CONTENTFLAG_BANNED_LOADED) {
            my $memval = LJ::MemCache::get("sysban:contentflag");
            if ($memval) {
                *LJ::CONTENTFLAG_BANNED = $memval;
                $LJ::CONTENTFLAG_BANNED_LOADED++;
            }
        }

        # is it already cached in memory?
        if ($LJ::CONTENTFLAG_BANNED_LOADED) {
            return (defined $LJ::CONTENTFLAG_BANNED{$value} &&
                    ($LJ::CONTENTFLAG_BANNED{$value} == 0 ||     # forever
                     $LJ::CONTENTFLAG_BANNED{$value} > time())); # not-expired
        }

        # set this now before the query
        $LJ::CONTENTFLAG_BANNED_LOADED++;

        LJ::sysban_populate(\%LJ::CONTENTFLAG_BANNED, "contentflag")
            or return undef $LJ::CONTENTFLAG_BANNED_LOADED;

        # set in memcache
        my $exp = 60*15; # 15 minutes
        LJ::MemCache::set("sysban:contentflag", \%LJ::CONTENTFLAG_BANNED, $exp);

        # return value to user
        return (defined $LJ::CONTENTFLAG_BANNED{$value} &&
                ($LJ::CONTENTFLAG_BANNED{$value} == 0 ||     # forever
                 $LJ::CONTENTFLAG_BANNED{$value} > time())); # not-expired
    }
    # cache if email_domain
    elsif ($what eq 'email_domain'){
        
        $value =~ s/^.*@//; ## in case $value is a full email address.

        # check memcache first if not loaded
        unless ($LJ::EMAIL_DOMAIN_BANNED_LOADED) {
            my $memval = LJ::MemCache::get("sysban:email_domain");
            if ($memval) {
                %LJ::EMAIL_DOMAIN_BANNED = %$memval;
                $LJ::EMAIL_DOMAIN_BANNED_LOADED++;
            }
        }

        # is it already cached in memory?
        if ($LJ::EMAIL_DOMAIN_BANNED_LOADED) {
            return (defined $LJ::EMAIL_DOMAIN_BANNED{$value} &&
                    ($LJ::EMAIL_DOMAIN_BANNED{$value} == 0 ||     # forever
                     $LJ::EMAIL_DOMAIN_BANNED{$value} > time())); # not-expired
        }

        # set this now before the query
        $LJ::EMAIL_DOMAIN_BANNED_LOADED++;

        LJ::sysban_populate(\%LJ::EMAIL_DOMAIN_BANNED, "email_domain")
            or return undef $LJ::EMAIL_DOMAIN_BANNED_LOADED;

        # set in memcache
        my $exp = 60*15; # 15 minutes
        LJ::MemCache::set("sysban:email_domain", \%LJ::EMAIL_DOMAIN_BANNED, $exp);

        # return value to user
        return (defined $LJ::EMAIL_DOMAIN_BANNED{$value} &&
                ($LJ::EMAIL_DOMAIN_BANNED{$value} == 0 ||     # forever
                 $LJ::EMAIL_DOMAIN_BANNED{$value} > time())); # not-expired
       
    }

    # need the db below here
    my $dbr = LJ::get_db_reader();
    return undef unless $dbr;

    # standard check helper
    my $check = sub {
        my ($wh, $vl) = @_;

        return $dbr->selectrow_array(qq{
                SELECT COUNT(*)
                FROM sysban
                WHERE status = 'active'
                  AND what = ?
                  AND value = ?
                  AND NOW() > bandate
                  AND (NOW() < banuntil
                       OR banuntil = 0
                       OR banuntil IS NULL)
            }, undef, $wh, $vl);
    };

    # check both ban by email and ban by domain if we have an email address
    if ($what eq 'email') {
        # short out if this email really is banned directly, or if we can't parse it
        return 1 if $check->('email', $value);
        return 0 unless $value =~ /@(.+)$/;

        # see if this domain is banned
        my @domains = split(/\./, $1);
        
        ## invalid domain of e-mail address
        return 1 if @domains<2;

        ## for email like 'name@abc.def.ghi.klm',
        ## check 'ghi.klm', 'def.ghi.klm' and 'abc.def.ghi.klm' domains
        my $checking_domain = pop @domains;
        while (@domains) {
            $checking_domain = pop(@domains) . "." . $checking_domain;
            return 1 if $check->('email_domain', $checking_domain);
        }

        # must not be banned
        return 0;
    }

    # non-ip bans come straight from the db
    return $check->($what, $value);
}

# takes a hashref to populate with 'value' => expiration pairs
# takes a 'what' to populate the hashref with sysbans of that type
# returns undef on failure, hashref on success
sub sysban_populate {
    my ($where, $what) = @_;

    ##
    return $where if LJ::is_enabled('load_sysbans_from_memcache_only');

    # call normally if no gearman/not wanted
    return LJ::_db_sysban_populate($where, $what) 
        unless LJ::conf_test($LJ::LOADSYSBAN_USING_GEARMAN);
    
    my $gc = LJ::gearman_client();
    return LJ::_db_sysban_populate($where, $what) 
        unless $gc;

    # invoke gearman
    my $args = Storable::nfreeze({what => $what});
    my $task = Gearman::Task->new("sysban_populate", \$args,
                                  {
                                      uniq => $what,
                                      on_complete => sub {
                                          my $res = shift;
                                          return unless $res;

                                          my $rv = Storable::thaw($$res);
                                          return unless $rv;

                                          $where->{$_} = $rv->{$_} foreach keys %$rv;
                                      }
                                  });
    my $ts = $gc->new_task_set();
    $ts->add_task($task);
    $ts->wait(timeout => 30); # 30 sec timeout

    return $where;
}

sub _db_sysban_populate {
    my ($where, $what) = @_;

    my $dbh = LJ::get_db_writer();
    return undef unless $dbh;

    # build cache from db
    my $sth = $dbh->prepare("SELECT value, UNIX_TIMESTAMP(banuntil) FROM sysban " .
                            "WHERE status='active' AND what=? " .
                            "AND NOW() > bandate " .
                            "AND (NOW() < banuntil OR banuntil IS NULL)");
    $sth->execute($what);
    return undef if $sth->err;
    while (my ($val, $exp) = $sth->fetchrow_array) {
        $where->{$val} = $exp || 0;
    }

    return $where;
}

# <LJFUNC>
# name: LJ::sysban_note
# des: Inserts a properly-formatted row into [dbtable[statushistory]] noting that a ban has been triggered.
# args: userid?, notes, vars
# des-userid: The userid which triggered the ban, if available.
# des-notes: A very brief description of what triggered the ban.
# des-vars: A hashref of helpful variables to log, keys being variable name and values being values.
# returns: nothing
# </LJFUNC>
sub sysban_note
{
    my ($userid, $notes, $vars) = @_;

    $notes .= ":";
    map { $notes .= " $_=$vars->{$_};" if $vars->{$_} } sort keys %$vars;
    LJ::statushistory_add($userid, 0, 'sysban_trig', $notes);

    return;
}

# <LJFUNC>
# name: LJ::sysban_block
# des: Notes a sysban in [dbtable[statushistory]] and returns a fake HTTP error message to the user.
# args: userid?, notes, vars
# des-userid: The userid which triggered the ban, if available.
# des-notes: A very brief description of what triggered the ban.
# des-vars: A hashref of helpful variables to log, keys being variable name and values being values.
# returns: nothing
# </LJFUNC>
sub sysban_block
{
    my ($userid, $notes, $vars) = @_;

    LJ::sysban_note($userid, $notes, $vars);

    my $msg = <<'EOM';
<html>
<head>
<title>503 Service Unavailable</title>
</head>
<body>
<h1>503 Service Unavailable</h1>
The service you have requested is temporarily unavailable.
</body>
</html>
EOM

    # may not run from web context (e.g. mailgated.pl -> supportlib -> ..)
    eval { BML::http_response(200, $msg); };

    return;
}

# <LJFUNC>
# name: LJ::sysban_create
# des: creates a sysban.
# args: what, value, bandays, note
# des-what: the criteria we're sysbanning on
# des-value: the value we're banning
# des-bandays: length of sysban (0 for forever)
# des-note: note to go with the ban (optional)
# info: Takes args as a hash.
# returns: 1 on success, 0 on failure
# </LJFUNC>
sub sysban_create {
    my %opts = @_;

    my $dbh = LJ::get_db_writer();

    my $status = $opts{status} eq 'expired' ? 'expired' : 'active';

    my $banuntil = $opts{banuntil} ? $dbh->quote($opts{banuntil}) : "NULL";
    if ($opts{'bandays'}) {
        $banuntil = "NOW() + INTERVAL " . $dbh->quote($opts{'bandays'}) . " DAY";
    }

    my $bandate  = $opts{bandate} ? $dbh->quote($opts{bandate}) : 'NOW()';

    # strip out leading/trailing whitespace
    $opts{'value'} = LJ::trim($opts{'value'});

    # do insert
    $dbh->do("INSERT INTO sysban (status, what, value, note, bandate, banuntil) VALUES (?, ?, ?, ?, $bandate, $banuntil)",
             undef, $status, $opts{'what'}, $opts{'value'}, $opts{'note'});
    return $dbh->errstr if $dbh->err;
    my $banid = $dbh->{'mysql_insertid'};

    my $exptime = $opts{bandays} ? time() + 86400*$opts{bandays} : 0;
    # special case: creating ip/uniq ban
    if ($opts{'what'} eq 'ip') {
        LJ::procnotify_add("ban_ip", { 'ip' => $opts{'value'}, exptime => $exptime });
        LJ::MemCache::delete("sysban:ip");
    }

    if ($opts{'what'} eq 'uniq') {
        LJ::procnotify_add("ban_uniq", { 'uniq' => $opts{'value'}, exptime => $exptime});
        LJ::MemCache::delete("sysban:uniq");
    }

    if ($opts{'what'} eq 'contentflag') {
        LJ::procnotify_add("ban_contentflag", { 'username' => $opts{'value'}, exptime => $exptime});
        LJ::MemCache::delete("sysban:contentflag");
    }

    if ($opts{'what'} eq 'ip_captcha'){
        LJ::CaptchaServer->ban_ip($opts{'value'});
    }

    # log in statushistory
    my $remote = LJ::get_remote();
    $banuntil = $opts{'bandays'} ? LJ::TimeUtil->mysql_time($exptime) : "forever";

    LJ::statushistory_add(0, $remote || 0, 'sysban_add',
                              "banid=$banid; status=$status; " .
                              "bandate=" . LJ::TimeUtil->mysql_time() . "; banuntil=$banuntil; " .
                              "what=$opts{'what'}; value=$opts{'value'}; " .
                              "note=$opts{'note'};");

    return $banid;
}


# <LJFUNC>
# name: LJ::sysban_validate
# des: determines whether a sysban can be added for a given value.
# args: type, value
# des-type: the sysban type we're checking
# des-value: the value we're checking
# returns: nothing on success, error message on failure
# </LJFUNC>
sub sysban_validate {
    my ($what, $value, $opts) = @_;

    # bail early if the ban already exists
    return "This is already banned"
        if !$opts->{skipexisting} && LJ::sysban_check($what, $value, $opts);
    
    my $ip_regexp = qr/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
    my $ip_to_str = sub { return pack("C4",split(/\./, $_[0])); }; 

    my $validate = {
        'ip' => sub {
            my $ip = shift;

            return "Format: xxx.xxx.xxx.xxx (ip address)" 
                unless $ip =~ /^$ip_regexp(?:\/\d+)?$/;

            my $tmp = new Net::IP ($ip) or
                return Net::IP::Error();

            while (my ($ip_re, $reason) = each %LJ::UNBANNABLE_IPS) {
                next unless $ip =~ $ip_re;
                return "Cannot ban IP $ip: " . LJ::ehtml($reason);
            }
 
            ## LJ::sysban_populate() doesn't return notes, so select them from DB
            my $dbh = LJ::get_db_reader()
                or die "Can't connect to db reader";
            my $whitelist = $dbh->selectall_arrayref(
                "
                    SELECT * 
                    FROM sysban 
                    WHERE what = 'ip_whitelist' 
                        AND status = 'active'
                        AND NOW() > bandate
                        AND (NOW() < banuntil
                           OR banuntil = 0
                           OR banuntil IS NULL)
                ",
                {Slice => {}}
            );
           
            ## if creting a new ban, check IP whitelist
            ## TODO: when modifying an existing ban, give a warning
            if (!$opts->{'skipexisting'}) { 
                my $matched_wl;
                foreach my $wl (@$whitelist) {
                    my $mask = $wl->{value}; ## see ip_whitelist below for possible formats
                    if ($mask =~ /^$ip_regexp$/) {
                        if ($mask eq $ip) {
                            $matched_wl = $wl;
                            last;
                        } 
                    } elsif (my ($start_ip, $end_ip) = $mask =~ /^($ip_regexp)-($ip_regexp)$/) {
                        if (    $ip_to_str->($start_ip) le $ip_to_str->($ip) && 
                                $ip_to_str->($ip) le $ip_to_str->($end_ip)) 
                        {
                            $matched_wl = $wl;
                            last;
                        }
                    } elsif ($mask =~ m!^$ip_regexp/(\d+)!) {
                        my $netmask = Net::Netmask->new($mask);
                        if ($netmask->match($ip)) {
                            $matched_wl = $wl;
                            last;
                        }
                    } elsif ($mask =~ /^(\d+\.){1,3}\*$/) {
                        $mask =~ s/\./\\./g;
                        $mask =~ s/\*/\.\*/;
                        if ($ip =~ /^$mask$/) {
                            $matched_wl = $wl;
                            last;
                        }
                    } else {
                        # hm...
                    }
                }

                if ($matched_wl) {
                    return "Can't ban ip address $ip: ip_whitelist #$matched_wl->{banid} matched ($matched_wl->{note})";
                }
            }     
                
            ## everything is ok
            return 0;
        },
        'uniq' => sub {
            my $uniq = shift;
            return $uniq =~ /^[a-zA-Z0-9]{15}$/ ?
                0 : "Invalid uniq: must be 15 digits/chars";
        },
        'email' => sub {
            my $email = shift;

            my @err;
            LJ::check_email($email, \@err);
            return @err ? shift @err : 0;
        },
        'email_domain' => sub {
            my $email_domain = shift;

            if ($email_domain =~ /^[^@]+\.[^@]+$/) {
                return 0;
            } else {
                return "Invalid email domain: $email_domain";
            }
        },
        'user' => sub {
            my $user = shift;

            my $u = LJ::load_user($user);
            return $u ? 0 : "Invalid user: $user";
        },
        'pay_cc' => sub {
            my $cc = shift;

            return $cc =~ /^\d{4}-\d{4}$/ ?
                0 : "Format: xxxx-xxxx (first four-last four)";

        },
        'msisdn' => sub {
            my $num = shift;
            return $num =~ /\d{10}/ ? 0 : 'Format: 10 digit MSISDN';
        },

        'ip_whitelist' => sub {
            my $mask = shift;
            $mask =~ s/\s+//g;
            
            ## allowed formats: exact IP address, range IP1-IP2, subnet: IP/num, mask: 123.456.*
            if (    $mask =~ /^$ip_regexp$/ || 
                    $mask =~ /^$ip_regexp-$ip_regexp$/ || 
                    $mask =~ m!^$ip_regexp/\d+$! ||
                    $mask =~ /^(\d+\.){1,3}\*$/ ) 
            {
                return 0;
            } else {
                return "Format: xxx.xxx.xxx.xxx (exact IP address), " .
                        "xxx.xxx.xxx.xxx-yyy.yyy.yyy.yyy (IP range),  " .
                        "xxx.xxx.xxx.xxx/yyy (subnet) or " .
                        "xxx.xxx.* (mask)";
            }
        }, 
    };

    # aliases to handlers above
    my @map = ('pay_user' => 'user',
               'pay_email' => 'email',
               'pay_uniq' => 'uniq',
               'support_user' => 'user',
               'support_email' => 'email',
               'support_uniq' => 'uniq',
               'lostpassword' => 'user',
               'lostpassword_email' => 'email',
               'talk_ip_test' => 'ip',
               'contentflag' => 'user',
               'ip_captcha'  => 'ip',
               );

    while (my ($new, $existing) = splice(@map, 0, 2)) {
        $validate->{$new} = $validate->{$existing};
    }

    my $check = $validate->{$what} or return "Invalid sysban type";
    return $check->($value);
}

1;
