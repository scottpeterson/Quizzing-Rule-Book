use Test::Most;
use exact -conf;
use Bible::Reference;
use Mojo::DOM;
use Mojo::File 'path';
use Text::MultiMarkdown 'markdown';

my $rule_book_dir = join( '/', map { conf->get(@$_) } (
    [ qw( config_app root_dir ) ],
    ['content_dir'],
    [ qw( rule_book dir ) ],
) );

my $tables;

lives_ok(
    sub {
        $tables = Mojo::DOM
            ->new( markdown( path("$rule_book_dir/index.md")->slurp ) )
            ->find('a')->map( attr => 'href' )->grep( sub { not m|//| } )->map( sub {
                Mojo::DOM->new(
                    markdown( path("$rule_book_dir/$_")->slurp
                ) )->find('table')->map( sub {
                    my $headers = $_->find('thead tr th')->map('text')->to_array;
                    my $node    = $_;
                    $node       = $node->previous while ( $node and $node->tag and $node->tag !~ /^h\d$/ );

                    {
                        header => ( ( $node and $node->text ) ? $node->text : 'Untitled' ),
                        rows   => $_->find('tbody tr')->map( sub {
                            my $row;
                            @$row{@$headers} = @{ $_->find('td')->map('text')->to_array };
                            $row;
                        } )->to_array,
                    };
                } );
            } )->grep( sub { $_->size } )->map( sub { @{ $_->to_array } } )->to_array
    },
    'parse content for tables',
);

my $material_years;
lives_ok( sub {
    $material_years = ( grep { $_->{header} eq 'Material Rotation Schedule' } @$tables )[0]->{rows};
}, 'find material years data' );

for my $year ( @{ conf->get( qw( table_data_tests material_style ) ) } ) {
    is(
        ( grep { $_->{'Material Scope References'} =~ /\b$year->[0]\b/ } @$material_years )[0]->{Style},
        $year->[1],
        "$year->[0] is $year->[1]",
    );
}

my @r;

lives_ok( sub {
    @r = Bible::Reference->new->in( map { $_->{'Material Scope References'} } @$material_years )->as_text;
}, 'Bible::Reference processing of Material Scope References' );

is_deeply(
    \@r,
    conf->get( qw( table_data_tests material_scope ) ),
    'Bible::Reference as_text check',
);

my $distribution;
lives_ok( sub {
    $distribution = ( grep { $_->{header} eq 'Question Type Distribution' } @$tables )[0]->{rows};
}, 'find distribution data' );

is_deeply(
    [ sort keys %{ $distribution->[0] } ],
    [
        'Maximum',
        'Minimum',
        'Question Types',
        'Type Group',
    ],
    'distribution table row has proper columns',
);

done_testing;
