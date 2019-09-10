package DBIx::Class::Weight;
use base qw(DBIx::Class);
use strict;
use warnings;
use Carp qw(carp);

our $VERSION = '1.0';

__PACKAGE__->mk_group_accessors(
  inherited => qw(weight_column weight_group_column)
);

__PACKAGE__->weight_column('weight');

=head1 NAME

DBIx::Class::Weight

=head1 DESCRIPTION

Provides methods for easily managing weighted rows.

Component requires you to specify a weight column,
and optionally a subclass column

The weight column should contain unique integers.

If a subclass column is specificed, the weight column is assumed to have one
unique group of integers for each subclass column.

=head1 SYNOPSIS

In your Result class:

  __PACKAGE__->load_components(qw/ Weight /);
  __PACKAGE__->add_columns(
    weight => { data_type => 'integer' },
    weight_group => { data_type => 'integer' }, # optional
  );
  __PACKAGE__->weight_column('weight');
  __PACKAGE__->weight_group_column('category'); # optional

Using the component

  # When a row is created, weight column is automatically
  # set to the current highest weight + 1, with L<next_weight>
  $row = $schema->resultset('Thing')->create(\%thing);

  # The weight values for the set can be easily adjusted
  $row->weight_up;
  $row->weight_down;

  @rows = $rs->search(undef, {order_by => 'weight'});

=head1 METHODS

=head2 insert

Hook into insert, set the value of weight column to next available value

=cut

sub insert {
    my $self = shift;
    $self->weight( $self->next_weight ) unless $self->weight;
    $self->next::method(@_);
}

=head2 next_weight

Get the next unused weight value

=cut

sub next_weight {
    my $self = shift;
    $self->_sanity_check;

    my $rs = $self->result_source->resultset->search({});
    $rs = $self->_rs_in_weight_group($rs);
    $rs = $self->_rs_ob_weight_desc($rs);
    if ( my $row = $rs->first ) {
        return $row->get_column( $self->weight_column ) + 1;
    }
    1;
}

=head2 weight_up

Move this record up in weight order

=cut

sub weight_up {
    my $self = shift;
    $self->_sanity_check;

    my $above_row = $self->_weight_row_above || return $self;
    $self->_exchange_weight_with( $above_row );
}

=head2 weight_down

Move this record down in weight order

=cut

sub weight_down {
    my $self = shift;
    $self->_sanity_check;

    my $below_row = $self->_weight_row_below || return $self;
    $self->_exchange_weight_with( $below_row );
}

sub _exchange_weight_with {
    my ($self, $ex) = @_;

    my $wc = $self->weight_column;
    my $old_w = $self->$wc;
    my $new_w = $ex->$wc;

    $self->update({ $wc => $new_w });
    $ex->update({ $wc => $old_w });
    $self;
}

sub _weight_row_above {
    my $self = shift;
    my $wc = $self->weight_column;

    my $rs =  $self->result_source->resultset->search(
        { $wc => { '<' => $self->$wc }},
    );
    $rs = $self->_rs_ob_weight_desc( $rs );
    $rs = $self->_rs_in_weight_group( $rs );

    $rs->first();
}

sub _weight_row_below {
    my $self = shift;
    my $wc = $self->weight_column;

    my $rs =  $self->result_source->resultset->search(
        { $wc => { '>' => $self->$wc }},
    );
    $rs = $self->_rs_ob_weight_asc( $rs );
    $rs = $self->_rs_in_weight_group( $rs );

    $rs->first();
}

sub _rs_in_weight_group {
    my ( $self, $rs ) = @_;
    my $wgc = $self->weight_group_column || return $rs;
    $rs->search({ $wgc => $self->$wgc });
}

sub _rs_ob_weight_desc {
    my ( $self, $rs ) = @_;
    $rs->search(undef, {order_by => {-desc => $self->weight_column}} );
}

sub _rs_ob_weight_asc {
    my ( $self, $rs ) = @_;
    $rs->search(undef, {order_by => {-asc => $self->weight_column}} );
}

sub _sanity_check {
    # If some idiocy, or race condition, has resulted in duplicate
    # weight values in a single group, reassign weight numbers
    # to the whole group.

    my ( $self ) = @_;
    my $rs = $self->result_source->resultset->search();
    my $wc = $self->weight_column;

    $rs = $self->_rs_in_weight_group($rs);
    $rs = $self->_rs_ob_weight_asc($rs);

    my @rows = $rs->all;
    my %w_map;
    $w_map{ $_->$wc }++ for @rows;

    if ( grep{ $_ > 1 } values %w_map ) {
        my $w = 1;
        $_->update({ $wc => $w++ }) for @rows;
        $self->discard_changes;
    }
}

=head1 COPYRIGHT AND LICENSE

This module is free software under the perl5 license

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com>

=cut

1;
