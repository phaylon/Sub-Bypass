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

do {
    my $x = let(do { 23 });
    is $x, 23, 'simple scalar';
    my @y = qw( a b c d );
    my $y = let(do { (my @f = qw( k l m n )); @f });
    is $y, 4, 'simple scalar with array';
    my $z = let(do { (my $x = 3); (my $y = 7); $x .. $y });
    is $z, 7, 'range in scalar context';
    my $h = let(do { my %h = (foo => 23); %h });
    isnt $h, 23, 'hash in scalar context';
    my $r = let(do { my $x = 23; $x ? (3 .. 6) : (2 .. 4) });
    is $r, 6, 'dynamic range in scalar context';
    # TODO causes read-only failure
    #my $r2 = let(do { 3 .. 6 });
    #is $r2, 6, 'static range in scalar context';
};

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

is let(let(23) + let(17)), 40, 'nested';
is_deeply [let(let(23), let(24))], [23, 24], 'nested list';

do {
    my $x = 17;
    my $y = 23;
    is_deeply [let(do {
            my ($n, $m) = ($x, $y);
            let(do {my $j = $n; $j }),
            let(do {my $k = $m; $k });
        })],
        [17, 23],
        'nested list with scopes and vars';
};

do {
    my $add = sub {
        let(do {
            (my $x = shift);
            (my $y = shift);
            return $x + $y unless shift;
            'inner-fallback';
        });
        'outer-return';
    };
    my $val = $add->(11, 12);
    is $val, 23, 'return from outer scope';
    my $no_ret = $add->(11, 12, 1);
    is $no_ret, 'outer-return', 'normal return';
};

done_testing;
