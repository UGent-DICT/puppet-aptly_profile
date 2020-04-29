# @summary converts permissions to apache requires and expands 'prefix' permissions
function aptly_profile::publish_auth_convert_allow_from_permission_to_requires(
  Aptly_profile::AllowFromPermissions $permission,
  Variant[Enum['authenticated'], Array[String[1], 1]] $shared_permissions,
) >> Aptly_profile::LocationRequires {

  $no_prefix = $permission ? {
    'prefix' => $shared_permissions,
    default  => $permission,
  }

  case $no_prefix {
    'authenticated': {
      $resolved_permissions = 'valid-user'
    }
    default: {
      $resolved_permissions = $no_prefix
    }
  }
  $resolved_permissions
}
