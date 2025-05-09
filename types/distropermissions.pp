# Represents pre-parsed permissions for a certain distribution within a prefix.
type Aptly_profile::DistroPermissions = Struct[{
  public => Optional[Aptly_profile::AllowFromPermissions],
  api    => Optional[Aptly_profile::AllowFromPermissions],
}]
