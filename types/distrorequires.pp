type Aptly_profile::DistroRequires = Struct[{
  'api'    => Optional[Aptly_profile::LocationRequires],
  'public' => Optional[Aptly_profile::LocationRequires],
}]
