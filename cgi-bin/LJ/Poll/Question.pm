package LJ::Poll::Question;
use strict;
use warnings;
use Carp qw (croak);
use Class::Autouse qw (
    LJ::Poll::Question::radio 
    LJ::Poll::Question::text
    LJ::Poll::Question::check
    LJ::Poll::Question::scale
    LJ::Poll::Question::drop
);

use Data::Dumper;

sub new {
    my ($class, $poll, $pollqid) = @_;

    my $self = {
        poll    => $poll,
        pollqid => $pollqid,
    };

    bless $self, $class;
    return $self;
}

sub new_from_row {
    my ($class, $row) = @_;

    my $pollid = $row->{pollid};
    my $pollqid = $row->{pollqid};

    my $poll;
    $poll = LJ::Poll->new($pollid) if $pollid;

    my $question = __PACKAGE__->new($poll, $pollqid);
    $question->absorb_row($row);

    return $question;
}

sub absorb_row {
    my ($self, $row) = @_;

    # items is optional, used for caching
    $self->{$_} = $row->{$_} foreach qw (sortorder type opts qtext items);
    $self->{_loaded} = 1;
}

sub _load {
    my $self = shift;
    return if $self->{_loaded};

    croak "_load called on a LJ::Poll::Question object with no pollid"
        unless $self->pollid;
    croak "_load called on a LJ::Poll::Question object with no pollqid"
        unless $self->pollqid;

    my $sth;

    if ($self->is_clustered) {
        $sth = $self->poll->journal->prepare('SELECT * FROM pollquestion2 WHERE pollid=? AND pollqid=? and journalid=?');
        $sth->execute($self->pollid, $self->pollqid, $self->poll->journalid);
    } else {
        my $dbr = LJ::get_db_reader();
        my $sth = $dbr->prepare('SELECT * FROM pollquestion WHERE pollid=? AND pollqid=?');
        $sth->execute($self->pollid, $self->pollqid);
    }

    $self->absorb_row($sth->fetchrow_hashref);
}

sub get_items {
    my $self = shift;
    my $type = $self->type;
    return "LJ::Poll::Question::$type"->out($self, @_)
}

sub stats {
    my $self = shift;
    my $type = $self->type;
    return "LJ::Poll::Question::$type"->stats($self, @_);
}

# returns the question rendered for previewing
sub preview_as_html {
    my $self = shift;
    my $ret = '';

    my $type = $self->type;
    my $opts = $self->opts;

    my $qtext = $self->qtext;
    if ($qtext) {
        LJ::Poll->clean_poll(\$qtext);
          $ret .= "<p>$qtext</p>\n";
      }
    $ret .= "<div style='margin: 10px 0 10px 40px'>";

    # text questions
    if ($type eq 'text') {
        my ($size, $max) = split(m!/!, $opts);
        $ret .= LJ::html_text({ 'size' => $size, 'maxlength' => $max });

        # scale questions
    } elsif ($type eq 'scale') {
        my ($from, $to, $by) = split(m!/!, $opts);
        $by ||= 1;
        my $count = int(($to-$from)/$by) + 1;
        my $do_radios = ($count <= 11);

        # few opts, display radios
        if ($do_radios) {
            $ret .= "<table><tr valign='top' align='center'>\n";
            for (my $at = $from; $at <= $to; $at += $by) {
                $ret .= "<td>" . LJ::html_check({ 'type' => 'radio' }) . "<br />$at</td>\n";
            }
            $ret .= "</tr></table>\n";

            # many opts, display select
        } else {
            my @optlist = ();
            for (my $at = $from; $at <= $to; $at += $by) {
                push @optlist, ('', $at);
            }
            $ret .= LJ::html_select({}, @optlist);
        }

        # questions with items
    } else {
        # drop-down list
        if ($type eq 'drop') {
            my @optlist = ('', '');
            foreach my $it ($self->items) {
                LJ::Poll->clean_poll(\$it->{item});
                  push @optlist, ('', $it->{item});
              }
            $ret .= LJ::html_select({}, @optlist);

            # radio or checkbox
        } else {
            foreach my $it ($self->items) {
                LJ::Poll->clean_poll(\$it->{item});
                  $ret .= LJ::html_check({ 'type' => $self->type }) . "$it->{item}<br />\n";
              }
        }
    }
    $ret .= "</div>";
    return $ret;
}

sub items {
    my $self = shift;

    return @{$self->{items}} if $self->{items};

    my $sth;

    if ($self->is_clustered) {
        $sth = $self->poll->journal->prepare('SELECT pollid, pollqid, pollitid, sortorder, item ' .
                                             'FROM pollitem2 WHERE pollid=? AND pollqid=? AND journalid=?');
        $sth->execute($self->pollid, $self->pollqid, $self->poll->journalid);
    } else {
        my $dbr = LJ::get_db_reader();
        $sth = $dbr->prepare('SELECT pollid, pollqid, pollitid, sortorder, item ' .
                                             'FROM pollitem WHERE pollid=? AND pollqid=?');
        $sth->execute($self->pollid, $self->pollqid);
    }

    die $sth->errstr if $sth->err;

    my @items;

    while (my $row = $sth->fetchrow_hashref) {
        my $item = {};
        $item->{$_} = $row->{$_} foreach qw(pollitid sortorder item pollid pollqid);
        push @items, $item;
    }

    @items = sort { $a->{sortorder} <=> $b->{sortorder} } @items;

    $self->{items} = \@items;

    return @items;
}

# accessors
sub poll {
    my $self = shift;
    return $self->{poll};
}
sub is_clustered {
    my $self = shift;
    return $self->poll->is_clustered;
}
sub pollid {
    my $self = shift;
    return $self->poll->pollid;
}
sub pollqid {
    my $self = shift;
    return $self->{pollqid};
}
sub sortorder {
    my $self = shift;
    $self->_load;
    return $self->{sortorder};
}
sub type {
    my $self = shift;
    $self->_load;
    return $self->{type};
}
sub opts {
    my $self = shift;
    $self->_load;
    return $self->{opts};
}
*text = \&qtext;
sub qtext {
    my $self = shift;
    $self->_load;
    return $self->{qtext};
}

sub get_hash {
    my $self = shift;
    my $res = {
                    pollqid => $self->pollqid,
                    type => $self->type,
                    sortorder => $self->sortorder,
              };

    my $text = $self->qtext;
    if ($text) {
        LJ::Poll->clean_poll(\$text);
        $res->{text} = $text;
    }

    my $opts = $self->opts;
    my @items = $self->items;
    @{$res->{items}} = map { delete $_->{pollid}; delete $_->{pollqid}; $_ } @items if (@items);

    if ($self->type eq 'text') {
        my ($size, $maxlength) = split(m!/!, $opts);
        $res->{size} = $size;
        $res->{maxlength} = $maxlength;
    } elsif ($self->type eq 'scale') {
        my ($from, $to, $by) = split(m!/!, $opts);
        $by ||= 1;
        $res->{from} = $from;
        $res->{to} = $to;
        $res->{by} = $by;
        my $num = 1;
        for (my $at = $from; $at <= $to; $at += $by) {
            push @{$res->{items}}, { item => $at, pollitid => $at, sortorder => $num++ };
        }
    }
    return $res;
}

sub get_question_xml {
    my $self = shift;
    my $ret;
    my $attrs = ' id="'.$self->pollqid.'" type="'.$self->type.'"';

    my $opts = $self->opts;
    if ($self->type eq 'text') {
        my ($size,$maxlength) = split(m!/!, $opts);
        $attrs .= ' size="'.$size.'" maxlength="'.$maxlength.'"';
    } elsif ($self->type eq 'scale') {
        my ($from, $to, $by) = split(m!/!, $opts);
        $by ||= 1;
        $attrs .= ' from="'.$from.'" to="'.$to.'" by="'.$by.'"';
    }
    $ret = "<lj-pq$attrs>";
    my $text = $self->qtext;
    if($text) {
        LJ::Poll->clean_poll(\$text);
        $ret .= $text;
    }
    my @items = $self->items;
    map { $ret .= '<lj-pi id="'.$_->{pollitid}.'" sortorder="'.$_->{sortorder}.'">'.$_->{item}.'</lj-pi>' } @items;
    $ret .= '</lj-pq>';
    return $ret;
}

# Count answers pages
sub answers_pages {
    my $self = shift;
    my $jid = shift;

    my $pagesize = shift || 2000;

    my $pages = 0;

    my $sth;

    if ($self->is_clustered) {
        # Get results count
        $sth = $self->poll->journal->prepare(
            "SELECT COUNT(*) as count".
            " FROM pollresult2".
            " WHERE pollid=? AND pollqid=? AND journalid=?");
        $sth->execute($self->pollid, $self->pollqid, $jid);
        die $sth->errstr if $sth->err;
        $_ = $sth->fetchrow_hashref;
        my $count = $_->{count};
        $pages = 1+int(($count-1)/$pagesize);
    } else {
        my $dbr = LJ::get_db_reader();
        # Get count
        $sth = $self->poll->journal->prepare(
            "SELECT COUNT(*) as count".
            " FROM pollresult".
            " WHERE pollid=? AND pollqid=?");
        $sth->execute($self->pollid, $self->pollqid);
        die $sth->errstr if $sth->err;
        $_ = $sth->fetchrow_hashref;
        my $count = $_->{count};
        $pages = 1+int(($count-1)/$pagesize);
    }
    die $sth->errstr if $sth->err;

    return $pages;
}

#
# this method is mysteriously duplicated below and should be removed, 
# when someone will make sure there are no 'hidden bombs'
#
sub answers_deprecated {
    my $self = shift;
    my $jid = shift;


    my $page     =  shift || 1;
    my $pagesize =  shift || 2000;

    my $pages = shift || $self->answers_pages($jid, $pagesize);

    my $sth;

    if ($self->is_clustered) {
        my $LIMIT = $pagesize * ($page - 1) . "," . $pagesize;

        # Get data
        $sth = $self->poll->journal->prepare(
            "SELECT pr.value, ps.datesubmit, pr.userid " .
            "FROM pollresult2 pr, pollsubmission2 ps " .
            "WHERE pr.pollid=? AND pollqid=? " .
            "AND ps.pollid=pr.pollid AND ps.userid=pr.userid " .
            "AND ps.journalid=? ".
            "LIMIT $LIMIT");
        $sth->execute($self->pollid, $self->pollqid, $jid);
    } else {
        my $dbr = LJ::get_db_reader();
        my $LIMIT = $pagesize  * ($page - 1) . "," . $pagesize;

        # Get data
        $sth = $dbr->prepare(
            "SELECT pr.value, ps.datesubmit, pr.userid ".
            "FROM pollresult pr, pollsubmission ps " .
            "WHERE pr.pollid=? AND pollqid=? " .
            "AND ps.pollid=pr.pollid AND ps.userid=pr.userid ".
            "LIMIT $LIMIT");
        $sth->execute($self->pollid, $self->pollqid);
    }
    die $sth->errstr if $sth->err;

    my ($pollid, $pollqid) = ($self->pollid, $self->pollqid);

    my @res;
    push @res, $_ 
        while $_ = $sth->fetchrow_hashref;

    foreach my $r (@res) {
        my @items = $self->items;

        my %it;
        $it{$_->{pollitid}} = $_->{item} 
            foreach @items;

        ## some question types need translation; type 'text' doesn't.
        if ($self->type eq "radio" || $self->type eq "drop") {
            $r->{value} = $it{$r->{value}};
        } elsif ($self->type eq "check") {
            $r->{value} = join(", ", map { $it{$_} } split(/,/, $r->{value}));
        }


    }
    
    return sort { $a->{datesubmit} cmp $b->{datesubmit} } @res;
}

sub answers_as_html {
    my $self = shift;
    my $ret = "<table>";
    my $entry_url = $self->poll->entry->url;
    
    foreach my $res ($self->answers(@_)) {
        my ($userid, $value, $jtalkid) = ($res->{userid}, $res->{value}, $res->{jtalkid});

        my $u = LJ::load_userid($userid) or die "Invalid userid $userid";

        LJ::Poll->clean_poll(\$value);
        
        
        
        my $comment_url = $value;
        if ($jtalkid) {
            my $comment  = LJ::Comment->new($self->poll->journalid, jtalkid => $jtalkid);
            my $dtalkid  = $comment->dtalkid;
            $comment_url = "&nbsp;&nbsp;&nbsp;<a href=\"" .
                           $entry_url . 
                           "?thread=" . 
                           $dtalkid . 
                           "#t" . 
                           $dtalkid . 
                           "\">" . 
                           $value . 
                           "</a>";
        }
        $ret .= "<tr><td>" . $u->ljuser_display . "</td><td>&nbsp;&nbsp;&nbsp;-- $comment_url </td></tr>\n";
    }

    $ret .= "</table>";
    
    return $ret;
}

sub paging_bar_as_html {
    my $self = shift;

    my $page  =  shift      || 1;
    my $pages =  shift      || 1;
    my $pagesize = shift    || 2000;

    my ($jid, $pollid, $pollqid) = @_;

    my $href_opts = sub {
        my $page = shift;
        return  "onclick=\"return LiveJournal.pollAnswerClick(event, {pollid:$pollid,pollqid:$pollqid,page:$page,pagesize:$pagesize})\"".
                " lj_posterid=\"$jid\"";
    };

    return LJ::paging_bar($page, $pages, { href_opts => $href_opts });
}

sub answers {
    my $self = shift;

    my $ret = '';
    my $answers;

    if ($self->is_clustered) {
        $answers = $self->poll->journal->selectall_hashref(
                                            qq(
                                                SELECT userid, 
                                                       pollqid, 
                                                       value 
                                                FROM   pollresult2
                                                WHERE  pollid=? 
                                                AND    pollqid=?
                                            ),
                                            'userid',
                                            undef,
                                            $self->pollid,
                                            $self->pollqid
                                         );
    } else {
        my $dbr = LJ::get_db_reader();
        $answers = $dbr->selectall_hashref(
                                            qq(
                                                SELECT userid, 
                                                       pollqid, 
                                                       value 
                                                FROM   pollresult
                                                WHERE  pollid=? 
                                                AND    pollqid=?
                                            ),
                                            'userid',
                                            undef,
                                            $self->pollid,
                                            $self->pollqid
                         );
    }

    my @voterids = $self->poll->get_voters_by_datesubmit;
    my %jtalks   = $self->poll->get_related_jtalks;
    
    my @items = $self->items;

    # define real values 
    my %it;
    $it{$_->{pollitid}} = $_->{item}
        foreach @items;

    my @res;

    foreach my $voter (@voterids) {
        my $answer = $answers->{$voter};
        if ($answer) {
            ## some question types need translation; type 'text' doesn't.
            if ($self->type eq "radio" || $self->type eq "drop") {
                $answer->{value} = $it{$answer->{value}};
            } elsif ($self->type eq "check") {
                $answer->{value} = join(", ", map { $it{$_} } split(/,/, $answer->{value}));
            }
            
            $answer->{jtalkid} = $jtalks{$voter};
            push @res, $answer;
        }
    }

    return @res;
}

1;
