use strictures 1;
use Test::More;
use Sub::Bypass;

BEGIN {
    install_bypassed_sub __PACKAGE__, 'let';
}

my @z = (3..9);
is +(my $y = scalar let do { @z }), 7, 'scalar context on array';
is_deeply [my @n = let do { @z }], \@z, 'list context on array' ;

sub foo { let do { @z } }
sub bar { let do { for (1..10) { return $_ if $_ == 8 } } }

is +(my $h = foo), 7, 'scalar context through sub';
is_deeply [my @h = foo], \@z, 'list context through sub';

is +(my $i = bar), 8, 'scalar context and loop';
is_deeply [my @i = bar], [8], 'list context and loop';

sub ctx { wantarray ? 'list' : 'scalar' }

is let(23), 23, 'simple scalar';
is +(my $s = let(@z)), 7, 'direct scalar context from assignment';

is scalar(let(do { ctx })), 'scalar', 'scalar context';
is [let(do { ctx })]->[0], 'list', 'list context';

my $code = sub { let do { localtime } };

is_deeply +{my %h = let(do { foo => 7, bar => 16 })},
    { foo => 7, bar => 16 },
    'hash assignment';

sub getwaval { let(do { wantarray ? 23 : 17 }) }

is +(my $x = getwaval), 17, 'wantarray in scalar context';
is_deeply [my @y = getwaval], [23], 'wantarray in list context';

sub getreturnval {
    let(do {
        return 93;
    });
    return 42;
}

is getreturnval, 93, 'explicit return';

ok not(__PACKAGE__->can('let')), 'not available as function';

done_testing;
