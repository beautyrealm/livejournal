package LJ::Widget::MarqueeFeatures;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use LJ::JSON;
use LJ::ExtBlock;

sub need_res {
    return qw( stc/widgets/widget-layout.css stc/widgets/marqueefeatures.css );
}

sub render_body {
    my $class = shift;
    my %opts = @_;

    my $params = {
        'marqueefeatures' => [
            'widget.marqueefeatures.title',
            'widget.marqueefeatures.also',
            'marquee_features',
        ],
        'majornotes' => [
            'widget.majornotes.title',
            'widget.majornotes.also',
            'major_notes',
        ],
        'featureshowcase' => [
            'widget.featureshowcase.title',
            'widget.featureshowcase.also',
            'feature_showcase',
        ],
        'majornotes_my' => [
            'widget.majornotes_my.title',
            'widget.majornotes_my.also',
            'major_notes_my',
        ],
        'featureshowcase_my' => [
            'widget.featureshowcase_my.title',
            'widget.featureshowcase_my.also',
            'feature_showcase_my',
        ],
    };

    my $type = $opts{'type'} || 'marqueefeatures';
    my ($subject, $see, $block) = @{$params->{$type}};
    my $marquee_features_json = LJ::ExtBlock->load_by_id($block);
    $marquee_features_json = $marquee_features_json->blocktext if $marquee_features_json;

    my $marquee_features = LJ::JSON->from_json($marquee_features_json);
    my $also = shift @$marquee_features;

    my $template = LJ::HTML::Template->new(
        { use_expr => 1 }, # force HTML::Template::Pro with Expr support
        die_on_bad_params => 0,
        strict => 0,
        filename => "$ENV{'LJHOME'}/templates/MarqueeFeatures/index.tmpl",
    );

    $template->param (
        also_text => $also->{text},
        also_link => $also->{link},
        links     => $marquee_features,
        subject   => LJ::Lang::ml($subject),
        see       => LJ::Lang::ml($see),
    );

    return $template->output;
}

1;
