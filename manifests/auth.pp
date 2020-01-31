# @summary Generate a apache config to control access to repositories (and published endpoints)
#
# Warning: When configuring any restriction on a published repository,
# this will require all published repositories to have authentication configured.
#
#
# @param config_path The path where to store the generated apache config file.
# @param passfile The password (htaccess, htdigest) file to use.
# @param auth_type Apache auth type (Basic, Digest).
# @param repos The repos hash. We will filter out allow_from rules.
# @param publish The publish hash. We will filter out allow_from rules.
#   As soon as one publish endpoint on the server has authentication,
#   you will need to use authentication for all repositories!
# @param owner Owner for the configuration file. Defaults to `$apache::user`.
# @param group Group for the configuration file. Defaults to `$apache::group`.
# @param mode Mode for the configuration file.
# @param api_path The path on which you exposed the api.
class aptly_profile::auth(
  Stdlib::Absolutepath $config_path,
  String $passfile = '/data/aptly/.aptly-passwdfile',
  String $auth_type = 'Basic',
  Hash $repos = {},
  Hash $publish = {},
  Optional[String] $owner = undef,
  Optional[String] $group = undef,
  Optional[String] $mode =  '0640',
  Stdlib::Absolutepath $api_path = '/api',
) {

  $file_owner = $owner ? {
    undef   => $::apache::user,
    default => $owner,
  }

  $file_group = $group ? {
    undef   => $::apache::group,
    default => $group,
  }

  concat {$config_path:
    ensure => 'present',
    mode   => $mode,
    owner  => $file_owner,
    group  => $file_group,
  }

  concat::fragment {'aptly_profile::auth':
    target  => $config_path,
    order   => 0,
    content => "# This file is managed by puppet and build from concat fragments in aptly_profile\n\n",
  }

  $repos.filter |$item| {
    $item[1].dig('allow_from') != undef and ! $item[1].dig('allow_from').empty()
  }.each |String $repo_name, Hash $config| {

    concat::fragment {"aptly_profile::auth: repo ${repo_name}":
      target  => $config_path,
      order   => 0,
      content => epp('aptly_profile/auth/apache_auth_repo.conf.epp', {
        auth_file  => $passfile,
        auth_type  => $auth_type,
        api_path   => $api_path,
        repo_name  => $repo_name,
        allow_from => $config['allow_from'],
      }),
    }
  }

  $restricted_publish = $publish.filter |$item| {
    $item[1].dig('allow_from') != undef and ! $item[1].dig('allow_from').empty()
  }
  unless $restricted_publish.empty() {
    $restricted_publish.each |String $publish_name, Hash $config| {
      concat::fragment {"aptly_profile::auth: publish ${name}":
        target  => $config_path,
        order   => 1,
        content => epp('aptly_profile/auth/apache_auth_publish.conf.epp', {
          auth_file    => $passfile,
          auth_type    => $auth_type,
          allow_from   => $config['allow_from'],
          publish_name => $publish_name,
        }),
      }
    }
    concat::fragment {'aptly_profile::auth: publish':
      target  => $config_path,
      order   => 2,
      content => epp('aptly_profile/auth/apache_auth_publish_pool.conf.epp', {
        auth_file => $passfile,
        auth_type => $auth_type,
      }),
    }
  }
}
