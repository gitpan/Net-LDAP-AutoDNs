package Net::LDAP::AutoDNs;

use warnings;
use strict;
use Sys::Hostname;

=head1 NAME

Net::LDAP::AutoDNs - Automatically make some default decisions some LDAP DNs and scopes.

=head1 VERSION

Version 0.1.0

=cut

our $VERSION = '0.1.0';


=head1 SYNOPSIS

    use Net::LDAP::AutoDNs;

    my $obj = Net::LDAP::AutoDNs->new();

    print $obj->{users}."\n";
    print $obj->{usersScope}."\n";
    print $obj->{dns}."\n";
    print $obj->{dnsScope}."\n";
    print $obj->{groups}."\n";
    print $obj->{groupsScope}."\n";
    print $obj->{home}."\n";
    print $obj->{base}."\n";

=head1 METHODS

=head2 new

Creates a new Net::LDAP::AutoDNs object.

=head3 hash args

=head4 methods

This is a comma seperated list of methods to use.

The currently supported ones are listed below and checked
in the listed order.

    devldap
    env
    hostname

The naming of those wraps around to the similarly named
methodes.

    #Only the hostname methode will be tried.
    my $obj=Net::LDAP::AutoDNs->({methodes=>"hostname"});
    
    #First the env methdoe will be tried and then the hostname methode.
    my $obj=Net::LDAP::AutoDNs->({methodes=>"env,hostname"})

=cut

sub new {
	my %args;
	if(defined($_[1])){
		%args= %{$_[1]};
	};

	#gets the methodes to use
	#This to make input from things other than perl easier.
	if (!defined($args{methodes})){
		$args{methodes}='devldap,env,hostname';
	}

	my $self={error=>undef, methodes=>$args{methodes}};

	bless $self;

	my $unmatched=1;

	#runs through the methodes and finds one to use
	my @split=split(/,/, $args{methodes}); #splits them apart at every ','
	my $splitInt=0;
	while (defined($split[$splitInt])){
		#handles it via the env method
		if ($unmatched && ($split[$splitInt] eq "devldap")) {
			if ($self->byDevLDAP()) {
				$unmatched=undef;#as it as been matched, set $unmatched to false
			}
		}

		#handles it via the env method
		if ($unmatched && ($split[$splitInt] eq "env")) {
			if ($self->byEnv()) {
				$unmatched=undef;#as it as been matched, set $unmatched to false
			}
		}

		#handles it if it if using the hostname method
		if ($unmatched && ($split[$splitInt] eq "hostname")) {
			if ($self->byHostname()) {
				$unmatched=undef;#as it as been matched, set $unmatched to false
			}
		}

		$splitInt++;
	}

	if ($unmatched){
		$self->{error}=2;
	}

	return $self;
}

=head2 byDevLDAP

This sets it up using the information found under '/dev/ldap/'.

More information on this can be found at
http://eesdp.org/eesdp/ldap-kmod.html .

=cut

sub byDevLDAP{
	my $self=$_[0];

	$self->{error}=undef;

	if (! -d '/dev/ldap/') {
		$self->{error}=3;
		return undef;
	}

	open(USERS, '<', '/dev/ldap/userBase');
	$self->{users}=join('', <USERS>);
	close(USERS);

	open(USERSSCOPE, '<', '/dev/ldap/userScope');
	$self->{usersScope}=join('', <USERSSCOPE>);
	close(USERSSCOPE);

	open(GROUP, '<', '/dev/ldap/groupBase');
	$self->{groups}=join('', <GROUP>);
	close(GROUP);

	open(GROUPSCOPE, '<', '/dev/ldap/groupScope');
	$self->{groupsScope}=join('', <GROUPSCOPE>);
	close(GROUPSCOPE);

	open(HOME, '<', '/dev/ldap/homeBase');
	$self->{home}=join('', <HOME>);
	close(HOME);

	open(BASE, '<', '/dev/ldap/base');
	$self->{base}=join('', <BASE>);
	close(BASE);

	$self->{dns}='ou=dns,'.$self->{base};
	$self->{dnsScope}='sub';
	$self->{dhcp}='ou=dhcp,'.$self->{base};
	$self->{dnsScope}='sub';

	return 1;
}

=head2 byEnv

This sets it up using $ENV{AutoDNbase} for the base.

=cut

sub byEnv{
	my $self=$_[0];
	my %args;

	#blanks any previous errors
	$self->{error}=undef;

	if (!defined($ENV{AutoDNbase})){
		return undef;
	}

	$self->{users}='ou=users,'.$ENV{AutoDNbase};
	$self->{usersScope}='sub';

	$self->{groups}='ou=groups,'.$ENV{AutoDNbase};
	$self->{groupsScope}='sub';

	$self->{home}='ou=home,'.$ENV{AutoDNbase};

	$self->{base}=$ENV{AutoDNbase};

	$self->{dhcp}='ou=dhcp,'.$ENV{AutoDNbase};
	$self->{dhcpScope}='sub';

	$self->{dns}='ou=dns,'.$ENV{AutoDNbase};
	$self->{dnsScope}='sub';

	return 1;
}

=head2 byHostname

Sets the DNs based on the hostname. The last subdomain is
chopped off and each '.' is replaced with a ',dc='. This
means 'host.foo.bar' becomes 'dc=foo,dc=bar'.

Returns true if it succeeds.

=cut

sub byHostname{
	my $self=$_[0];
	my %args;


	#blanks any previous errors
	$self->{error}=undef;

	my $base=hostname;#gets the hostname
	if ($?) {
		$self->{error}=1;
		return undef;
	}
	chomp($base);#removes the trailing '\n'
	$base=~s/^[a-z0-9A-Z-]*\.//; #removes everything up to the first '.'
	$base=~s/\./,dc=/g;#replaces every '.' with a ',dc='
	$base='dc='.$base;#creates fine base dn


	$self->{users}='ou=users,'.$base;
	$self->{usersScope}='sub';

	$self->{groups}='ou=groups,'.$base;
	$self->{groupsScope}='sub';

	$self->{home}='ou=home,'.$base;

	$self->{base}=$base;

	$self->{dhcp}='ou=dhcp,'.$base;
	$self->{dhcpScope}='sub';

	$self->{dns}='ou=dns,'.$base;
	$self->{dnsScope}='sub';

	return 0;
}

=head1 Error Codes

$obj->{error} is defined, there is an error.

=head2 0

Methode not implemented yet.

=head2 1

Retrieving hostname failed. Most likely caused by 'hostname' not being in the path.

=head2 2

None of the methodes returned matched or returned true.

=head2 3

Either the system does not support /dev/ldap/.

=head1 AUTHOR

Zane C. Bowers, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-ldap-autodns at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-LDAP-AutoDNs>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::LDAP::AutoDNs


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-LDAP-AutoDNs>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-LDAP-AutoDNs>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-LDAP-AutoDNs>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-LDAP-AutoDNs>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Zane C. Bowers, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Net::LDAP::AutoDNs
