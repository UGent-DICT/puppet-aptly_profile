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
  Aptly_profile::AllowFromKeywords $default_allow_from = 'prefix',
  Boolean $strict = false,
)
>> Hash[String, Aptly_profile::PrefixRequires]
{

  $sorted_by_prefix = aptly_profile::publish_auth_order_by_prefix($publish)
  $sanitized_by_prefix = aptly_profile::publish_auth_clean_and_default_prefixes($default_allow_from, $sorted_by_prefix, $prefixes)

  $sanitized_by_prefix.reduce({}) |Hash $memo, Tuple $element| {
    $prefix = $element[0]

    $expanded = aptly_profile::publish_auth_resolve_permissions_by_prefix($prefix, $element[1])
    $shared_permissions = aptly_profile::publish_auth_resolve_shared_permissions($element[1])

    # @TODO: Strict mode and permissions checking. Failing if there are gaps and such.

    deep_merge($memo, { $prefix => {
      'pool'  => $shared_permissions,
      'dists' => $expanded,
    }})
  }
}
