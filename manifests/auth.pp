# @summary Generate an apache config to control access to the api and public folder.
#
# For repositories, we configure authentication to for the `/api/repos` and `/api/files` endpoints.
# For published distributions, we configure authentiation for the `/api/publish` endpoint and
# `public/` folder (for each prefix and distribution).
# See the note below on the `/pool/` directory inside `/public/`
#
# ## Attention:
#
# Some paths are shared between distributions within the same prefix.
#
# * The `/pool/` directory in each prefix is shared for all distributions within the same prefix!
#   All users that have access to any distribution in this prefix will have access to the files
#   in that pool directory.
# * The `^/api/publish$` endpoint can be called from all permissions on all prefixes.
#   Note that any api endpoint is only exposed when enable_api is `true`.
#
# For the most secure configuration, you should use a dedicated prefix for each set of permissions.
#
#
# @param config_path The path where to store the generated apache config file.
# @param passfile The password (htaccess, htdigest) file to use.
# @param auth_type Apache auth type (Basic, Digest).
#
# @param default_allow_from Default allow_from parameter for distributions. This
# is only used for distributions that exist in a prefix where other distributions
# need authorization.
# @param strict_publish @TODO
#
# @param repos The repos hash. We will filter out allow_from rules.
# @param publish The publish hash. We will filter out allow_from rules.
#   As soon as one publish endpoint on the server has authentication,
#   you will need to use authentication for all repositories!
# @param prefixes A hash with a default allow_from for a specific prefix.
# @param owner Owner for the configuration file. Defaults to `$apache::user`.
# @param group Group for the configuration file. Defaults to `$apache::group`.
# @param mode Mode for the configuration file.
# @param api_path The path on which you exposed the api.
class aptly_profile::auth(
  Stdlib::Absolutepath $config_path,
  String $passfile = '/data/aptly/.aptly-passwdfile',
  String $auth_type = 'Basic',

  Aptly_profile::AllowFromKeywords $default_allow_from = 'prefix',
  Boolean $strict_publish = false,

  Hash $repos = {},
  Hash $publish = {},
  Hash $prefixes = {},
  String $owner = $::apache::user,
  String $group = $::apache::group,
  String $mode = '0640',
  Stdlib::Absolutepath $api_path = '/api',
  Boolean $enable_api = $::aptly_profile::enable_api,
) {

  concat {$config_path:
    ensure => 'present',
    mode   => $mode,
    owner  => $owner,
    group  => $group,
  }

  concat::fragment {'aptly_profile::auth':
    target  => $config_path,
    order   => 0,
    content => "# This file is managed by puppet and build from concat fragments in aptly_profile\n\n",
  }

  # Get all entries that are not ensure 'absent' since those will be unmanaged.
  $ensured_publish = $publish.filter |$item| {
    $item[1].dig('ensure') != 'absent'
  }

  $restricted_publish = aptly_profile::convert_publish_allow_from_to_requires(
    $ensured_publish, $prefixes, $default_allow_from, $strict_publish
  )

  if $enable_api {
    # for repos, we only have api access rules to define.
    $repos.filter |$item| {
      $item[1].dig('allow_from') != undef and ! $item[1].dig('allow_from').empty() and $item[1].dig('ensure') != 'absent'
    }.each |String $repo_name, Hash $config| {

      concat::fragment {"aptly_profile::auth: repo ${repo_name}":
        target  => $config_path,
        order   => 1,
        content => epp('aptly_profile/auth/apache_auth_repo.conf.epp', {
          api_path   => $api_path,
          auth_file  => $passfile,
          auth_type  => $auth_type,
          repo_name  => $repo_name,
          allow_from => $config['allow_from'],
        }),
      }
    }

    if $restricted_publish.size() > 0 {
      # resolve the shared permissions for all prefixes to allow access to the shared ^/api/publish$
      # @todo: add a flag to disable /api/publish
      $global_shared_permissions = $restricted_publish.reduce({}) |Hash $memo, Tuple $element| {
        $memo + { $element[0] => $element[1]['pool'] }
      }

      if ('valid-user' in $global_shared_permissions.values()) {
        $global_shared_require = 'valid-user'
      }
      else {
        $global_shared_require = $global_shared_permissions.filter() |$_, $v| {
          $v =~ Array
          }.values().flatten().sort().unique()
      }

      # TODO: Strict mode disabled /api/publish endpoint (unless all permissions are equal over all prefixes?)
      concat::fragment {"aptly_profile::auth: api public shared":
        target  => $config_path,
        order   => 3,
        content => epp('aptly_profile/auth/apache_auth_publish_api_shared.conf.epp', {
          api_path  => $api_path,
          auth_file => $passfile,
          auth_type => $auth_type,
          require   => $global_shared_require,
          }),
      }

      $restricted_publish.each |String $prefix, Aptly_profile::PrefixRequires $requires| {
        concat::fragment {"aptly_profile::auth: api public prefix ${prefix}":
          target  => $config_path,
          order   => 5,
          content => epp('aptly_profile/auth/apache_auth_publish_api_prefix.conf.epp', {
            api_path  => $api_path,
            auth_file => $passfile,
            auth_type => $auth_type,
            prefix    => $prefix,
            requires  => $requires,
            }),
        }
      }
    }
  }

  # Restrict access for <datadir>/public/
  $restricted_publish.each |String $prefix, Aptly_profile::PrefixRequires $requires| {
    concat::fragment {"aptly_profile::auth: public publish prefix ${prefix}":
      target  => $config_path,
      order   => 7,
      content => epp('aptly_profile/auth/apache_auth_publish_prefix.conf.epp', {
        auth_file => $passfile,
        auth_type => $auth_type,
        prefix    => $prefix,
        requires  => $requires,
        }),
    }
  }
}
