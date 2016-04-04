#!/usr/bin/env bash

# There is the temporary solution allows to use the Assume Role parameter in aws-ruby-sdk.
# This script contains patch and allows to apply or revert it.

# Put the patch content to the variable $PATCH
read -r -d '' PATCH <<EOP
70c70
<       @credentials = Credentials.new(
---
>       credentials = Credentials.new(
74a75,83
>       @credentials = if role_arn = profile['role_arn']
>         AssumeRoleCredentials.new(
>           role_session_name: [*('A'..'Z')].sample(16).join,
>           role_arn: role_arn,
>           credentials: credentials
>         ).credentials
>       else
>         credentials
>       end
79c88,92
<         profile
---
>         if source = profile.delete('source_profile')
>           profiles[source].merge(profile)
>         else
>           profile
>         end
EOP

# Define the target gem and file
GEM_NAME='aws-sdk-core'
FILE_NAME='shared_credentials.rb'

# Find the latest version of gem file
GEM_FILE=$(gem contents "${GEM_NAME}" | grep "${FILE_NAME}")

# Define the commands
TEST_COMMAND='echo "${PATCH}" | patch --dry-run --force --silent '"${GEM_FILE} $@"
PATCH_COMMAND='echo "${PATCH}" | patch '"${GEM_FILE} $@"

# Parse arguments
while [ $# -gt 0 ]
do
  case "$1" in
    --help|-h|-\?) pod2usage -verbose 1 "$0"; exit 0 ;;
    --man) pod2usage -verbose 2 "$0"; exit 0 ;;
    --dry-run) shift; echo == Command: ==; echo "$PATCH_COMMAND"; exit 0 ;;
    -R|--reverse) shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

eval $TEST_COMMAND && eval $PATCH_COMMAND
exit $?

__END__

=pod

=head1 NAME

aws-sdk-patch.sh - Apply or revert patch to aws-ruby-sdk to enable the support of Assume roles

=head1 SYNOPSIS

aws-sdk-patch.sh [OPTIONS]

=head1 OPTIONS

=over 4

=item B<--help> | B<-h>

Print the brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<-R> | B<--reverse>

Revert the previously applied patch

=item B<--dry-run>

Print the command and  results of applying the patches without actually changing any files.

=back

=head1 ARGUMENTS

Arguments are not allowed.

=head1 DESCRIPTION

There is the temporary solution allows to use the Assume Role parameter in aws-ruby-sdk. This script contains patch and allows to apply or revert it.

=head1 SEE ALSO

GIT PR #1092, https://github.com/aws/aws-sdk-ruby/pull/1092

=head1 AUTHOR

Serhiy Suprun <serhiy.suprun@bazaarvoice.com>

=cut
