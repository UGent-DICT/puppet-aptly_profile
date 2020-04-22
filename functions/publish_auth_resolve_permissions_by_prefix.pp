# @summary Resolve all permissions for a prefix.
#
# This will resolve all permissions to proper Aptly_profile::LocationRequires.
# @param prefix Unused except for error messages.
# @param distributions Sanitized list of distribution permissions.
function aptly_profile::publish_auth_resolve_permissions_by_prefix(
  String $prefix,
  Hash[String, Aptly_profile::DistroPermissions, 1] $distributions,
)
>> Hash[String, Aptly_profile::LocationRequires]
{

  $shared_permissions = aptly_profile::publish_auth_resolve_shared_permissions($distributions)

  if $shared_permissions.empty() {
    $errmsg = @("ERRMSG")
      Unable to resolve permissions in prefix '${prefix}'.
      You need to specify at least one user or 'authenticated' in a prefix.
    | ERRMSG
    fail($errmsg)
  }

  $distributions.reduce({}) |Hash $memo, Tuple[String, Aptly_profile::DistroPermissions] $element| {
    $distro = $element[0]
    $permissions = $element[1]
    case $permissions {
      'prefix': {
        $resolved_permissions = $shared_permissions
      }
      'authenticated': {
        $resolved_permissions = 'valid-user'
      }
      default: {
        $resolved_permissions = $permissions
      }
    }
    deep_merge($memo, { $distro => $resolved_permissions })
  }
}
