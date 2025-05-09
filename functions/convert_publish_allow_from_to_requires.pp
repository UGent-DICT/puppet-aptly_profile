# @summary Convert publish end point configuration to apache require statements
#
# @param publish List of publish endpoints as given to aptly_profile.
# @param prefixes A hash with overrides for the default allow_from for a certain prefix.
#   For the root prefix, use `''` (empty string).
# @param default_allow_from Default value to use in a prefix when no allow_from is provided for a distribution.
#   Note, if a prefix has no distributions with allow_from config, it will NOT be included in
#   result.
# @param strict Enable strict mode. This will fail the puppet run whenever
#   distributions have conflicting allow_from configuration within a prefix.
#   Currently NOT implemented.
function aptly_profile::convert_publish_allow_from_to_requires(
  Hash[String, Hash] $publish,
  Hash $prefixes = {},
  Hash $repos = {},
  Aptly_profile::AllowFromKeywords $default_allow_from = 'prefix',
  Boolean $strict = false,
) >> Hash[String, Aptly_profile::PrefixRequires] {

  # convert to hash with prefix => distribution_points => {}
  $sorted_by_prefix = aptly_profile::publish_auth_order_by_prefix($publish, $repos)
  # remove all prefixes without any authorization
  $sanitized_by_prefix = aptly_profile::publish_auth_clean_and_default_prefixes($default_allow_from, $sorted_by_prefix, $prefixes)

  $sanitized_by_prefix.reduce({}) |Hash $memo, Tuple[String, Aptly_profile::PrefixPermissions] $element| {
    $prefix = $element[0]
    $distributions = $element[1]

    $expanded = aptly_profile::publish_auth_resolve_permissions_by_prefix($prefix, $element[1])
    $api_shared_permissions = $expanded
                                .aptly_profile::publish_auth_collect_permissions_by_type('api')
                                .aptly_profile::publish_auth_resolve_shared_permissions()

    unless $api_shared_permissions.empty() {
      assert_type(Aptly_profile::LocationRequires, $api_shared_permissions)
    }

    $public_shared_permissions = $expanded
                                   .aptly_profile::publish_auth_collect_permissions_by_type('public')
                                   .aptly_profile::publish_auth_resolve_shared_permissions()
    unless $public_shared_permissions.empty() {
      assert_type(Aptly_profile::LocationRequires, $public_shared_permissions)
    }

    # @TODO: Strict mode and permissions checking. Failing if there are gaps and such.
    $api = $api_shared_permissions.empty() ? {
      true    => {},
      default => { 'api' => $api_shared_permissions },
    }
    $pool = $public_shared_permissions.empty() ? {
      true    => {},
      default => {'pool' => $public_shared_permissions },
    }

    $prefix_expanded = $api + $pool + { 'dists' => $expanded }
    assert_type(Aptly_profile::PrefixRequires, $prefix_expanded)

    deep_merge($memo, { $prefix => $prefix_expanded })
  }
}
