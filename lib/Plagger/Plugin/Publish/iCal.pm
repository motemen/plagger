package Plagger::Plugin::Publish::iCal;
use strict;
use base qw( Plagger::Plugin );

use File::Spec;
use Data::ICal;
use Data::ICal::Entry::Event;
use DateTime::Duration;
use DateTime::Format::ICal;
use Plagger::Util;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'publish.feed' => \&publish_feed,
        'plugin.init ' => \&plugin_init,
    );
}

sub plugin_init {
    my($self, $context) = @_;

    my $dir = $self->conf->{dir};
    unless (-e $dir && -d _) {
        mkdir $dir, 0755 or $context->error("Failed to mkdir $dir: $!");
    }
}

sub _dt_to_ical {
    my ($dt) = @_;

    my $p = [ $dt->format('ICal'), {} ];
    $p->[0] =~ s/^TZID=(.*?)://
        and $p->[1]->{TZID} = $1;

    if ($dt->hms eq '00:00:00') {
        $p->[1]->{VALUE} = 'DATE';
    }

    return $p;
}

sub publish_feed {
    my($self, $context, $args) = @_;

    my $feed = $args->{feed};
    my $ical = Data::ICal->new;
    $ical->add_properties(
        'X-WR-CALNAME'  => $feed->title,
    );

    for my $entry ($feed->entries) {
        my $event = Data::ICal::Entry::Event->new;

        my $dtstart = _dt_to_ical($entry->date);
        my $dtend =
            ref $entry->{ical_dtend} ? _dt_to_ical($entry->{ical_dtend})
            : $entry->{ical_dtend}   ? _dt_to_ical(Plagger::Date->parse_dwim($entry->{ical_dtend}))
            : $dtstart;
        $event->add_properties(
            summary     => $entry->title,
            description => $entry->summary ? $entry->summary->plaintext : '',
            dtstart     => $dtstart,
            dtend       => $dtend,
            url         => $entry->link,
        );
        $event->add_properties(location => $entry->location) if $entry->location;
        $ical->add_entry($event);
    }

    my $file = Plagger::Util::filename_for($feed, $self->conf->{filename} || '%i.ics');
    my $path = File::Spec->catfile($self->conf->{dir}, $file);

    my $data = $ical->as_string;
    utf8::decode($data) unless utf8::is_utf8($data);

    open my $output, ">:utf8", $path or $context->error("$path: $!");
    print $output $data;
    close $output;

    $context->log(info => "Wrote iCalendar file to $path");
}

1;
__END__

=head1 NAME

Plagger::Plugin::Publish::iCal - Produces iCal file out of the feed

=head1 SYNOPSIS

  - module: Publish::iCal
    config:
      dir: /path/to/dir

=head1 DESCRIPTION

Publish::iCal creates iCal (.ics) files using feed items. Every feed
is a calendar and each entry is a schedule item. Entry's posted
date/time is used as a schedule date/time and so on.

=head1 CONFIG

=over 4

=item dir

Directory to save ics files in.

=item filename

filename to save ics files as. Defaults to I<%i.ics>.

=back

=head1 AUTHOR

Kentaro Kuribayashi

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plagger>, L<Data::ICal>

=cut
