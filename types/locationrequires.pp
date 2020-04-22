# Represents authorization configuration for a certain location. Can be a keyword or an array of users.
type Aptly_profile::LocationRequires = Variant[
  Enum['valid-user','all granted'],
  Array[String, 1],
]
