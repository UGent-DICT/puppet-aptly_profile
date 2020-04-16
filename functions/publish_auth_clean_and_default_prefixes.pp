# @summary Sanitizes publish points configuration
#
# This function will:
# * remove any prefix that has no distributions that have authorization configuration
# * default any distribution that has no authorization configuration in a prefix that remains after cleanup
# * the default to use for any prefix can be configured using prefix_defaults or the `default` parameter is used.
#
# @param default Any not undef value (since we replace undef values)
# @param prefixed Distributions configuration ordered by prefix.
# @private
function aptly_profile::publish_auth_clean_and_default_prefixes(
  NotUndef $default,
  Hash[String, Hash] $prefixed,
  Hash $prefix_defaults = {},
) >> Hash[String, Hash[String, NotUndef, 1]] {

  $filtered_all_empty_prefix = $prefixed.filter |String $prefix, Aptly_profile::PrefixPermissions $distributions| {
    $not_undef_size = $distributions.filter |$_name, $permissions| {
      $permissions =~ NotUndef
    }.size()
    $not_undef_size > 0
  }

  $filtered_all_empty_prefix.reduce({}) |Hash $memo, Tuple $element| {
    $prefix = $element[0]
    $default_value = $prefix in $prefix_defaults ? {
      true    => $prefix_defaults[$prefix],
      default => $default,
    }

    $distributions = $element[1].reduce({}) |Hash $_memo, Tuple $_element| {
      deep_merge($_memo, { $_element[0] => pick($_element[1], $default_value) })
    }

    deep_merge($memo, { $prefix => $distributions })
  }

}
