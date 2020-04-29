# @summary Find matching repos with permissions for the publish api
# @param publish_params The raw publish configuration
# @param repos A hash with all configured repositories.
# @return The combined permissions for all repos used in this publish endpoint.
function aptly_profile::publish_auth_resolve_api_permissions(
  Hash[String, Any] $publish_params,
  Hash[String, Any] $repos,
) >> Optional[Aptly_profile::AllowFromPermissions] {

  $components = pick($publish_params.dig('components'), {})

  $referenced_repos = $components.map |String $component, Hash $component_params| {
    $component_params.dig('repo')
  }.filter() |Optional[String] $p| { $p =~ NotUndef }

  $repos_permissions = $referenced_repos.map() |String $repo| {
    $repos.dig($repo, 'allow_from')
  }
  $shared_permissions = aptly_profile::publish_auth_resolve_shared_permissions($repos_permissions)

  $return = $shared_permissions.empty() ? {
    true    => undef,
    default => $shared_permissions,
  }
}
