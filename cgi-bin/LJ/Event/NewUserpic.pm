package LJ::Event::NewUserpic;
use strict;
use base 'LJ::Event';
use Class::Autouse qw(LJ::Entry);
use Carp qw(croak);

sub new {
    my ($class, $up) = @_;
    croak "No userpic" unless $up;

    return $class->SUPER::new($up->owner, $up->id);
}

sub as_string {
    my $self = shift;

    return $self->event_journal->display_username . " has uploaded a new userpic.";
}

sub as_html {
    my $self = shift;
    my $up = $self->userpic;
    return "(Deleted userpic)" unless $up && $up->valid;

    return $self->event_journal->ljuser_display . " has uploaded a new <a href='" . $up->url . "'>userpic</a>.";
}

sub tmpl_params {
    my ($self, $u) = @_;

    my $up = $self->userpic;
    my $lang = $u->prop('browselang') || $LJ::DEFAULT_LANG;

    return { 
        body    => LJ::Lang::get_text($lang, 'esn.new_userpic.nouserpic.params.body'), 
        subject => LJ::Lang::get_text($lang, 'esn.new_userpic.nouserpic.params.subject'), 
    }  unless $up && $up->valid;

    return { 
        body    => LJ::Lang::get_text($lang, 'esn.new_userpic.params.body', undef, { user => $self->event_journal->ljuser_display, url => $up->url}),
        userpic => $up->url,
        subject => LJ::Lang::get_text($lang, 'esn.new_userpic.params.subject'),
    }
}

sub as_sms {
    my ($self, $u) = @_;
    my $lang = ($u && $u->prop('browselang')) || $LJ::DEFAULT_LANG;

# [[journal]] has uploaded a new userpic. You can view it at: [[pic_url]]
    return LJ::Lang::get_text($lang, 'notification.sms.newuserpic', undef, {
        journal => $self->event_journal->display_username(1),
        pic_url => $self->userpic->url,
    });
}

# esn.new_userpic.alert=[[who]] has uploaded a new userpic. You can view it at: [[userpic]].

sub as_alert {
    my $self = shift;
    my $u = shift;
    my $who = $self->event_journal;
    my $userpic = $self->userpic->url;
    return '' unless $who && $userpic;
    return LJ::Lang::get_text($u->prop('browselang'),
        'esn.new_userpic.alert', undef, { who => $who->ljuser_display(), userpic => $userpic });
}

sub as_email_string {
    my ($self, $u) = @_;
    return unless $self->userpic && $self->userpic->valid;

    my $username = $u->user;
    my $poster = $self->userpic->owner->user;
    my $userpic = $self->userpic->url;
    my $journal_url = $self->userpic->owner->journal_base;
    my $profile = $self->userpic->owner->profile_url;

    my $email = "Hi $username,

$poster has uploaded a new userpic! You can see it at:
   $userpic

You can:

  - View all of $poster\'s userpics:
    $LJ::SITEROOT/allpics.bml?user=$poster";

    unless (LJ::is_friend($u, $self->userpic->owner)) {
        $email .= "
  - Add $poster as a friend:
    $LJ::SITEROOT/friends/add.bml?user=$poster";
    }

$email .= "
  - View their journal:
    $journal_url
  - View their profile:
    $profile\n\n";

    return $email;
}


sub as_email_html {
    my ($self, $u) = @_;
    return unless $self->userpic && $self->userpic->valid;

    my $username = $u->ljuser_display;
    my $poster = $self->userpic->owner->ljuser_display;
    my $postername = $self->userpic->owner->user;
    my $userpic = $self->userpic->imgtag;
    my $journal_url = $self->userpic->owner->journal_base;
    my $profile = $self->userpic->owner->profile_url;

    my $email = "Hi $username,

$poster has uploaded a new userpic:
<blockquote>$userpic</blockquote>
You can:<ul>";

    $email .= "<li><a href=\"$LJ::SITEROOT/allpics.bml?user=$postername\">View all of $postername\'s userpics</a></li>";
    $email .= "<li><a href=\"$LJ::SITEROOT/friends/add.bml?user=$postername\">Add $postername as a friend</a></li>"
        unless (LJ::is_friend($u, $self->userpic->owner));
    $email .= "<li><a href=\"$journal_url\">View their journal</a></li>";
    $email .= "<li><a href=\"$profile\">View their profile</a></li></ul>";

    return $email;
}

sub userpic {
    my $self = shift;
    my $upid = $self->arg1 or die "No userpic id";
    return eval { LJ::Userpic->new($self->event_journal, $upid) };
}

sub content {
    my $self = shift;
    my $up = $self->userpic;

    return undef unless $up && $up->valid;

    return $up->imgtag;
}

sub as_email_subject {
    my $self = shift;
    return sprintf "%s uploaded a new userpic!", $self->event_journal->display_username;
}

sub zero_journalid_subs_means { "friends" }

sub subscription_as_html {
    my ($class, $subscr) = @_;
    my $journal = $subscr->journal;

    # "One of my friends uploads a new userpic"
    # or "$ljuser uploads a new userpic";
    return $journal ?
        LJ::Lang::ml('event.userpic_upload.user',
            { user => $journal->ljuser_display }) :
        LJ::Lang::ml('event.userpic_upload.me');
}

sub available_for_user  {
    my ($self, $u) = @_;

    return 1 unless $self->userid;
    return $u->get_cap("track_user_newuserpic") ? 1 : 0;
}

sub is_tracking { 0 }

sub as_push {
    my $self = shift;
    my $u = shift;
    my $lang = shift;

    return LJ::Lang::get_text($lang, "esn.push.notification.newuserpic", 1, {
        user        => $self->event_journal->user(),
    })
}

sub as_push_payload {
    my $self = shift;

    return { 't' => 16,
             'j' => $self->event_journal->user(),
           };
}


1;
