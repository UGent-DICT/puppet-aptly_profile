# Format a LocationRequires so you can use 'Require <%= aptly_profile::format_require($require) %>' in templates.
function aptly_profile::format_require(
  Aptly_profile::LocationRequires $require
) >> String {
  if $require =~ Array {
    "user ${require.join(' ')}"
  }
  else {
    $require
  }
}
