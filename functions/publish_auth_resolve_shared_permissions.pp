# @summary helper to resolve shared permissions
#
# As soon as any permissions is configured as 'authenticated',
# the shared permissions will also be 'authenticated'
# Otherwise, the result is a combination of all users in the provided permissions.
#
# @param permissions The permissions which to resolve.
# @return Either a valid Aptly_profile::LocationRequires or an empty array (when no users can be collected)
function aptly_profile::publish_auth_resolve_shared_permissions(
  Array[Optional[Variant[Aptly_profile::AllowFromPermissions, Aptly_profile::LocationRequires]]] $permissions,
) >> Variant[Aptly_profile::AllowFromPermissions, Array[String, 0, 0], Aptly_profile::LocationRequires] {

  $values = $permissions.filter() |$p| { $p =~ NotUndef }

  if ('authenticated' in $values) {
    $return = 'authenticated'
  }
  elsif ('valid-user' in $values) {
    $return = 'valid-user'
  }
  else {
    $return = $values.filter() |Aptly_profile::AllowFromPermissions $p| { $p =~ Array }.flatten().sort().unique()
  }
}
