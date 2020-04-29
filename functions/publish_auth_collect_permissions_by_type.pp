# @summary Collect permissions from a sub-hash/struct
# @param elements Hash with subhashes to get a field from.
# @param type The subkey to fetch.
# @return An array with all sub values that are not undef.
# @private
function aptly_profile::publish_auth_collect_permissions_by_type(
  Hash[String, Hash, 1] $elements,
  String[1] $type,
) >> Array[NotUndef] {

  $elements.reduce([]) |Array[NotUndef] $memo, Tuple $element| {
    $distro = $element[0]
    $permissions = $element[1]
    if $permissions.dig($type) =~ NotUndef {
      $memo + [ $permissions[$type] ]
    }
    else {
      $memo
    }
  }

}
