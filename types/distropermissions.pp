# Represent possible permissions that can be configured for a published distribution or a prefix pool. Either a keyword or an array of usernames.
type Aptly_profile::DistroPermissions = Variant[
  Aptly_profile::AllowFromKeywords,
  Array[String, 1],
]
