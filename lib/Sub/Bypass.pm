use strictures 1;

# ABSTRACT: Replaces sub calls with the sub arguments

package Sub::Bypass;

use B;
use B::Generate                         1.37;
use B::Flags                            0.04;
use Check::UnitCheck                    0.13;
use B::Hooks::OP::Check::EntersubForCV  0.06;
use Sub::Install                        0.925   qw( install_sub );

use namespace::clean 0.20;
use Sub::Exporter 0.982 -setup => {
    exports => [qw( install_bypassed_sub )],
    groups  => {
        default => [qw( install_bypassed_sub )],
    },
};

sub install_bypassed_sub {
    my ($package, $name, %callback) = @_;
    install_sub {
        into => $package,
        as   => $name,
        code => sub { die "This should never run" },
    };
    my @ops;
    B::Hooks::OP::Check::EntersubForCV->import($package->can($name), sub {
        my ($code, $op) = @_;
        push @ops, $op;
        $callback{on_parse}->($op)
            if $callback{on_parse};
    });
    Check::UnitCheck::unitcheckify(sub {
        for my $op (@ops) {
            _debug('*', transform => _id($op));
            _dump(before => $op);
            my ($list) = $op->kids;
            my $next = $op->next;
            my $gv = _iterate($list->first, sub {
                my $curr = shift;
                if ($curr->name eq 'gv' and ${$curr->next} == $$op) {
                    return $curr;
                }
                return undef;
            });
            _recurse($list->first, sub {
                my $curr = shift;
                my $prev = shift;
                _debug(rec => _id($curr));
                if (${$curr->next} == $$gv) {
                    _debug(target => _id($curr), before => _id($gv));
                    _transfer_context($op, $curr);
                    if ($prev->name =~ m/^pad.v$/) {
                        _debug(pad => _id($prev));
                        _transfer_context($op, $prev);
                    }
                    _connect($curr, $next);
                }
                return undef;
            });
            _nullify($gv);
            _debug(list_first => _id($list->first));
            _nullify($list->first);
            my $lfn = $list->first->next;
            if ($lfn->name eq 'enter') {
                _debug(list_first_next => _id($lfn));
            }
            _nullify($op);
            _dump(after => $op);
            namespace::clean->clean_subroutines($package, $name);
        }
    });
}

sub _dump  {
    return unless $ENV{SYNTAX_LET_DUMP};
    print uc(shift), ' ';
    (shift)->dump;
}

sub _debug {
    return unless $ENV{SYNTAX_LET_DEBUG};
    warn sprintf "%s\n", join ' ', @_;
}

sub _connect {
    my ($op, $next) = @_;
    _debug(connect => _id($op), '=>', _id($next));
    $op->next($next);
    return 1;
}

sub _id {
    my ($op) = @_;
    return sprintf 'gv[%s]', $op->gv->NAME
        if $op->name eq 'gv';
    return $op->name;
}

sub _nullify {
    my ($op) = @_;
    _debug(nulled => _id($op));
    $op->type(0);
    return 1;
}

sub _transfer_context {
    my ($from, $to) = @_;
    _debug(flags_before => _id($to), $to->flagspv);
    $to->flags(($to->flags - _get_context($to)) + _get_context($from));
    _debug(flags_after => _id($to), $to->flagspv);
    return 1;
}

sub _get_context {
    my ($op) = @_;
    my $flags = $op->flagspv;
    return  $flags =~ m/LIST/   ? 3
        :   $flags =~ m/SCALAR/ ? 2
        :   $flags =~ m/VOID/   ? 1
        :   0;
}

sub _iterate {
    my ($search, $test) = @_;
    while ($search->can('next') and my $current = $search->next) {
        if (defined( my $value = $current->$test )) {
            return $value;
        }
        $search = $current;
    }
    return undef;
}

sub _recurse {
    my ($search, $run, $seen) = @_;
    $seen ||= {};
    while (my $current = $search->next) {
        return unless $current->can('name');
        return if $$current == $$search;
        unless ($seen->{ $$current }++) {
            $current->$run($search) and return 1;
            if ($current->can('other') and $current->other) {
                unless ($seen->{ ${$current->other} }++) {
                    $current->other->$run($current) and return 1;
                    _recurse($current->other, $run, $seen) and return 1;
                }
            }
        }
        $search = $current;
    }
    return undef;
}

1;

__END__

=head1 SYNOPSIS

    package MySetup;
    use strictures 1;
    use Sub::Bypass;

    sub import {
        install_bypassed_sub scalar(caller), 'foo';
    }

    1;
    ...

    package MyUsing;
    use strictures 1;
    use MySetup;

    # foo() never gets called
    # $count is 4
    my @items = qw( a b c d );
    my $count = foo(do { @items });

    1;

=head1 DESCRIPTION

This module is B<EXPERIMENTAL>. If you're not sure what it's for, don't
touch it.

This module allows to install a subroutine that will be replaced with its
arguments.  This means that (assuming C<foo> is the bypassed sub)

    say foo(23);

is basically the same as

    say 23;

=head1 EXPORTS

=head2 install_bypassed_sub

    install_bypassed_sub($target_package, $sub_name);

Needs to be called during the compilation stage (typically inside of a
C<import> method).

=head1 CAVEATS

=over

=item *

I have no idea about perl's internals.

=item *

It's written using L<B::Generate> containing lots of hacks that I'm not sure
how or why they work or are necessary. It would probably be safer if it were
rewritten in XS by someone who knows what they're doing.

=item *

It messes up L<B::Deparse> (I think).

=item *

It uses L<Check::UnitCheck> to perform OP tree manipulation at C<CHECK> or
C<UNITCHECK> time. I have no idea if this makes sense in this context, or if
it might mess up environments like mod_perl.

=back

=head1 SEE ALSO

L<B>, L<B::Generate>, L<Check::UnitCheck>.

=cut
