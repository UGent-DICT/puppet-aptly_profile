# @summary Sanitizes publish points configuration
#
# This function will:
# * remove any prefix that has no distributions that have authorization configuration
# * default any distributions 'public' that has no authorization configuration in a prefix that remains after cleanup
# * the default to use for any prefix can be configured using prefix_defaults or the `default` parameter is used.
#
# @param default Any 'public' not undef value (since we replace undef values)
# @param prefixed Distributions configuration ordered by prefix.
# @private
function aptly_profile::publish_auth_clean_and_default_prefixes(
  NotUndef $default,
  Hash[String, Aptly_profile::PrefixPermissions] $prefixed,
  Hash $prefix_defaults = {}, # @TODO: Properly type prefixes.
) >> Hash[String, Hash[String, NotUndef, 1]] {

  $filtered_all_empty_public_prefix = $prefixed.filter()
      |String $prefix, Aptly_profile::PrefixPermissions $distributions| {

    $not_undef_size = $distributions.filter |$_name, $permissions| {
      $permissions['public'] =~ NotUndef
    }.size()
    $not_undef_size > 0
  }

  $public_defaulted = $filtered_all_empty_public_prefix.reduce({})
      |Hash $memo, Tuple[String, Aptly_profile::PrefixPermissions] $element| {
    $prefix = $element[0]

    $default_value = $prefix in $prefix_defaults ? {
      true    => $prefix_defaults[$prefix],
      default => $default,
    }

    $distributions = $element[1].reduce({}) |Hash $_memo, Tuple $_element| {
      deep_merge($_memo, { $_element[0] => { 'public' => pick($_element[1]['public'], $default_value)}})
    }

    deep_merge($memo, { $prefix => $distributions })
  }


  $filtered_api_only = $prefixed.reduce({}) |Hash $memo, Tuple $element| {
    $prefix = $element[0]
    $distributions = $element[1]

    $distributions_api_only = $distributions.reduce({}) |Hash $_memo, Tuple $_element| {
      $distro = $_element[0]
      $permissions = $_element[1]
      if $_element[1].dig('api') =~ NotUndef {
        deep_merge($_memo, { $distro => {'api' => $_element[1]['api'] }})
      }
      else {
        $_memo
      }
    }
    if $distributions_api_only.size() > 0 {
      deep_merge($memo, { $prefix => $distributions_api_only })
    }
    else {
      $memo
    }
  }

  deep_merge($public_defaulted, $filtered_api_only)

}
