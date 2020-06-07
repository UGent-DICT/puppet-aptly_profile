# @summary Represents authorization configuration for a prefix with distributions.
type Aptly_profile::PrefixRequires = Struct[{
  Optional[api] => Aptly_profile::LocationRequires, # not required but if present, should be a valid location requirement.
  Optional[pool] => Aptly_profile::LocationRequires, # not required but if present, should be a valid location requirement.
  dists => Hash[String, Aptly_profile::DistroRequires, 1], # Should not be empty, cleanup should have been done already.
}]
