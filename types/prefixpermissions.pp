# Represent possible distributions configuration for a prefix.
type Aptly_profile::PrefixPermissions = Hash[String, Optional[Aptly_profile::DistroPermissions]]
