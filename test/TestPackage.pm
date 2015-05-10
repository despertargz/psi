package TestPackage;

use MooseX::Params::Validate;

sub awesome_method {
	my ($self, %params) = validated_hash(
		\@_,
		name => { isa => 'Str' },
		age => { isa => 'Int' }
	);
}

sub pos_method {
	my ($self, $name, $age) = post_validated_list(
		\@_,
		{ isa => 'Str' },
		{ isa => 'Int' }
	);
}


sub cool_method {
	my $p = shift;
    my $x = $_[1];
	my ($name, $age) = @_;
	my ($self, $name, $age) = validated_list(
		\@_,
		name => { isa => 'Str' },
		age => { isa => 'Int' }
	)
	# nothing to see here
}

1;
