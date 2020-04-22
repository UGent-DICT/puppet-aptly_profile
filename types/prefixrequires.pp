# Represents authorization configuration for a prefix with distributions.
type Aptly_profile::PrefixRequires = Variant[
  Aptly_profile::LocationRequires,
  Struct[{
    pool  => Aptly_profile::LocationRequires,
    dists => Hash[String, Aptly_profile::LocationRequires],
  }]
]
