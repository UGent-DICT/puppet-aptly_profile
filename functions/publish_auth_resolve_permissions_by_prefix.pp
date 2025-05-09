# @summary Resolve all permissions for a prefix.
#
# This will resolve all permissions to proper Aptly_profile::LocationRequires.
# @param prefix Unused except for error messages.
# @param distributions Sanitized list of distribution permissions.
function aptly_profile::publish_auth_resolve_permissions_by_prefix(
  String $prefix,
  Hash[String, Aptly_profile::DistroPermissions, 1] $distributions,
)
>> Hash[String, Aptly_profile::DistroRequires]
{

  $public_permissions = $distributions.aptly_profile::publish_auth_collect_permissions_by_type('public')

  $public_shared_permissions = aptly_profile::publish_auth_resolve_shared_permissions($public_permissions)

  if $public_permissions.size() > 0 and $public_shared_permissions.empty() {
    $errmsg = @("ERRMSG")
      Unable to resolve permissions in prefix '${prefix}'.
      You need to specify at least one user or 'authenticated' in a prefix.
    | ERRMSG
    fail($errmsg)
  }

  $api_permissions = $distributions.aptly_profile::publish_auth_collect_permissions_by_type('api')
  $api_shared_permissions = aptly_profile::publish_auth_resolve_shared_permissions($api_permissions)

  $distributions.reduce({}) |Hash $memo, Tuple[String, Aptly_profile::DistroPermissions] $element| {
    $distro = $element[0]
    $public_permission = $element[1].dig('public')
    $api_permission = $element[1].dig('api')

    $resolved_public = $public_permission ? {
      undef   => {},
      default => {
        'public' => aptly_profile::publish_auth_convert_allow_from_permission_to_requires($public_permission, $public_shared_permissions),
      },
    }
    $resolved_api = $api_permission ? {
      undef   => {},
      default => {
        'api' => aptly_profile::publish_auth_convert_allow_from_permission_to_requires($api_permission, $api_shared_permissions),
      },
    }
    $resolved_permissions = {} + $resolved_api + $resolved_public

    deep_merge($memo, { $distro => $resolved_permissions })
  }
}
