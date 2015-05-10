#! /usr/bin/env perl

use strict;
use warnings;

use File::Find;
#use File::Grep 'fgrep';
use File::Slurp;
use Data::Dumper;
use DBI;
use YAML 'LoadFile';
use FindBin '$Bin';

my $config = LoadFile("$Bin/config.yaml");
print Dumper($config);

my $dbh = DBI->connect("dbi:mysql:database=" . $config->{db_name} . ";host=" . $config->{db_host}, $config->{db_user}, $config->{db_pass}, { RaiseError => 1 });

my $dir = shift @ARGV;
find(\&process_file, ($dir));

sub save_property {
    my $package_id = shift; 
    my $name = shift;

    $dbh->do("insert into properties (name, package_id, type) values (?,?,?)", undef, $name, $package_id, 'property');
}

sub save_method {
    my $package_id = shift;
    my $name = shift;
    my $params = shift;
     
    $dbh->do("insert into properties (name, package_id, type) values (?,?,?)", undef, $name, $package_id, 'sub');
    if (!$params) {
        return;
    }

    my $property_id = $dbh->{mysql_insertid};
    print Dumper($params);
    
    foreach my $method_name (keys $params) {
        my $method_type = $params->{$method_name};
            
        $dbh->do("insert into params (name, property_id, type) values (?,?,?)", undef, $method_name, $property_id, $method_type);
    }

}

sub save_package {
    my $name = shift;
    my $file = shift;

    my $package = $dbh->selectall_arrayref('select * from packages where name = ?', { Slice => {} }, $name)->[0];
    if (!$package) {
        my $source = read_file($file);
        $dbh->do('insert into packages (name, file, source) values (?,?,?)', undef, $name, $file, $source);
        my $package_id = $dbh->{mysql_insertid};

        my @tags = split /::/, $name;
        foreach my $tag (@tags) {
            $dbh->do('insert into tags (name, package_id) values (?,?)', undef, $tag, $package_id);
        }

        return $package_id;
    }
    else {
        my $properties = $dbh->selectall_arrayref('select name, type from properties where package_id = ?', { Slice => {} }, $package->{id});
        my %prop_hash = map { $_->{type} . ' ' . $_->{name} => 1 } @{$properties};
        return $package->{id}, \%prop_hash;
    }
}

sub process_file {
    my $file = $File::Find::name;
    if (!($file =~ /.pm$/)) {
        return;
    }

    my $package = `grep -Po '^package \\K(.+)' $file | head -n1`;
    chop $package;
    chop $package;

    my @props = `grep -Po '^\s*has \\K(.+)' $file`;
    chomp @props;

    map { s/ =>.*// } @props;
    map { s/^'// } @props;
    map { s/'$// } @props;


    print $package, "\n";
    print $file, "\n";
    print "\n";

    my ($package_id, $prop_hash) = save_package($package, $file);

    print "subroutines\n";
    my @subs = parse_subs($file);
    foreach my $sub (@subs) {
        my $params = get_method_params($sub->{text});
        print Dumper($sub->{text});
        print Dumper($params);
          
        if (!$prop_hash->{'sub ' . $sub}) {
            save_method($package_id, $sub->{name}, $params);
            print "\t$sub->{name}\n";
        }
    } 

    print "properties\n";
    foreach my $prop (@props) {
        if (!$prop_hash->{'property ' . $prop}) {
            save_property($package_id, $prop);
            print "\t$prop\n";
        }
    } 

    print "---\n";
    print "\n";
}

sub get_method_params {
    my $method_text = shift;

    if ($method_text =~ /validated_hash|validted_list/) {
        return get_method_params_validated_hash($method_text);
    }
    else {
        return undef;
    }
}

sub get_method_params_validated_hash {
    my $method_text = shift;
    
    my @params = ();
    push(@params, $1 => $2) while ($method_text =~ /(\w+).*isa.*\s'?([\w|:]+)'?\s/g); 
    my %hash = @params; 
    return \%hash;
}

sub parse_subs {
    my $file = shift;

    my $file_text = read_file($file);
    my @subs = ();
    my $sub = undef;
    my $brace_count = 0;

    my @lines = split /\n/, $file_text;

    foreach my $line (@lines) {
        if (!$sub && $line =~ /sub (\w+)/) {
            print "creating sub $1\n";
            $sub = {
                name => $1,
                text => [] 
            };
        
            $brace_count = 0; 
            $line = '{';
        }

        my @chars = split //, $line;
        print "char split: @chars\n";

        foreach my $char (@chars) {
            if ($char eq '{') {
                $brace_count++;
                print "brace count: $brace_count\n";
            }
            elsif ($char eq '}') {
                $brace_count--;
                print "brace count: $brace_count\n";
            }

            if ($sub) {
                push($sub->{text}, $char);
                print("pushing $char\n");
                if ($brace_count == 0) {
                    $sub->{text} = join('', @{$sub->{text}});
                    push(@subs, $sub); 
                    $sub = undef;    
                    last;
                }
            }
        }

        if ($sub) {
            push($sub->{text}, "\n");
        } 
    }

    return @subs;
}


