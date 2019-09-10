# NAME

DBIx::Class::Weight

# DESCRIPTION

Provides methods for easily managing weighted rows.

Component requires you to specify a weight column,
and optionally a subclass column

The weight column should contain unique integers.

If a subclass column is specificed, the weight column is assumed to have one
unique group of integers for each subclass column.

# SYNOPSIS

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

# METHODS

## insert

Hook into insert, set the value of weight column to next available value

## next\_weight

Get the next unused weight value

## weight\_up

Move this record up in weight order

## weight\_down

Move this record down in weight order

# COPYRIGHT AND LICENSE

This module is free software under the perl5 license

(c) 2019 Mitch Jackson <mitch@mitchjacksontech.com>
