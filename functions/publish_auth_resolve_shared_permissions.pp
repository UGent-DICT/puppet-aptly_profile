# @summary resolve permissions to use for 'prefix'
#
# As soon as any distribution is configured as 'authenticated',
# the shared permissions will also be 'authenticated'
# Otherwise, the result is a combination of all users in the prefix.
#
# @param distributions The distribution permissions within a prefix.
# @return Either a valid Aptly_profile::LocationRequires or an empty array (when no users can be collected)
function aptly_profile::publish_auth_resolve_shared_permissions(
  Aptly_profile::PrefixPermissions $distributions,
) >> Variant[Aptly_profile::LocationRequires, Array[String, 0, 0]] {
  if ('authenticated' in $distributions.values()) {
    $return = 'valid-user'
  }
  else {
    $return = $distributions.filter() |String $_, $p| { $p =~ Array }.values().flatten().sort().unique()
  }
}
