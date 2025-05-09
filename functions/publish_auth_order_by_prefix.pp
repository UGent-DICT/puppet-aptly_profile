# @summary Split a list of publish points by their prefix
#
# Splits the publish endpoints in a hash by-prefix and validates the allow_from
# parameter for each distribution if it has been configured.
#
# @example publish point configuration (in yaml)
#
#   # parameter publish being:
#   publish:
#     foobar:
#       components: {}
#     main/foo:
#       components:
#         test:
#           repo: testrepo
#       param1: value1
#     main/bar:
#       allow_from: [user]
#       param2: value2
#
#   # parameter repos being:
#   repos:
#     testrepo:
#       allow_from: [admin]
#
#
#   # returned result:
#   result:
#     '':
#       foobar:
#         public: nil
#         api: nil
#     'main':
#       'foo':
#         public: nil
#         api: [admin]
#       'bar':
#         public: [user]
#         api: nil
#
# @param publish A hash of publish endpoints.
function aptly_profile::publish_auth_order_by_prefix(
  Hash $publish,
  Hash $repos,
)
>> Hash[String, Hash[String, Aptly_profile::DistroPermissions]]
{

  $unsorted = $publish.reduce({}) |Hash $memo, Tuple[String, Hash] $element| {
    $publish_point = $element[0]
    $publish_params = $element[1]

    if ($publish_point =~ /(?:(.*)\/)?([^\/]+)/) {
      $prefix = String.new($1) # Creates empty string if undef.
      $distribution = $2
    }
    else {
      fail("Unable to parse the endpoint into a prefix and distribution: '${publish_point}'")
    }

    if $publish_params.dig('allow_from') =~ NotUndef {
      assert_type(Aptly_profile::AllowFromPermissions, $publish_params['allow_from']) |$expected, $actual| {
        fail("Parameter 'allow_from' for publish point '${publish_point}' expects a ${expected}. Not '${publish_params['allow_from']}'")
      }
      $public_allow_from = $publish_params['allow_from'] ? {
        Array   => $publish_params['allow_from'].sort(),
        default => $publish_params['allow_from'],
      }
    }
    else {
      $public_allow_from = undef
    }

    $api_allow_from = aptly_profile::publish_auth_resolve_api_permissions($publish_params, $repos)
    $distribution_params = { 'public' => $public_allow_from, 'api' => $api_allow_from }
    deep_merge($memo, { $prefix => { $distribution => $distribution_params, }})
  }

  # sort by prefix and by distribution.
  $unsorted.keys.sort.reduce({}) |Hash $memo, String $prefix| {
    $pubpoints = $unsorted[$prefix].keys.sort.reduce({}) |Hash $pm, String $pubpoint| {
      $pm + { $pubpoint => $unsorted.dig($prefix, $pubpoint) }
    }
    $memo + { $prefix => $pubpoints }
  }

}
