#
# Installs an aptly server on the host, mirrors the repos listed in hiera, and
# serves the (manually) published repos via apache.
#
# Note: If the private (secret) aptly key changes, all other trusted keys
# will need to be re-imported. (This should only be a problem if you added
# keys manually.)
#
# @param aptly_user         User aptly is running as.
# @param aptly_uid          Uid for the aptly user, needs to be fixed for backup/restore to work properly
# @param aptly_group        Group aptly is running as.
# @param aptly_homedir      Homedir for aptly.
# @param aptly_shell        Shell for user aptly.
# @param aptly_config       Additional config to pass through to aptly. Note: datadir is enforced.
# @param manage_user        Manage the aptly user.
# @param manage_group       Manage the aptly group.
# @param manage_homedir     Manage the homedir.
# @param manage_apache      Manage apache and vhost configuration.
# @param cleanup_defaults   String with default options to pass on to a cleanup for a repo
# @param gpg_uid            Configure the UID for a newly generated gpg key.
# @param gpg_import_apt     Import the generated key in apt immediately.
# @param gpg_path           Override gpg binary to use. Defaults to the gpg_path fact or '/usr/bin/gpg'
# @param trusted_keys       Hash with trusted keys.
# @param publish            Hash with the publish configuration.
# @param mirrors            Hash with the mirrors to configure.
# @param repos              Hash with the repositories to create.
# @param mirror_defaults    Hash with default properties to set on mirrors.
#   Note, we map the environment property to `aptly_environment` by default even if it is
#   not defined in the mirror_defaults.
# @param repo_defaults      Hash with default properties to set on repos.
# @param aptly_environment  An array with custom environment settings for the cron job.
# @param publish_defaults   A hash with default properties to set on publishing points.
# @param insert_hello Boolean indicating if you want te hello world package to be included
#   in newly created repositories.
# @param aptly_cache_dir    Directory where aptly can cache some data (the hello world package)
# @param enable_api         Wether to config & start the Aptly API service
# @param proxy_api          Should the API service get proxied (this makes it accessible on https).
# @param proxy_api_htpasswd_users Hash of users: htpasswd for proxied API access
# @param api_vhost          When the api service is proxied, this will be the vhost name that is used.
# @param api_ensure         Service ensure param
# @param api_user           User for Aptly API. Default 'aptly'
# @param api_group          Group for Aptly API. Default 'users'
# @param api_listen_ip      Ip to listen on. Default '127.0.0.1'
# @param api_listen_port    Port to listen on. Default 8080
# @param api_enable_cli_and_http  Allow combined use of Aptly API & CLI
# @param force_https_reverse_proxy Force rewrites to https if we are behind a reverse proxy (looking at x-forwareded-proto)
# @param export_auth_file If set, the module will generate a apache configuration file
#   limiting the use of repos (api) and/or publish endpoints.
# @param export_auth_type The apache authentication type (Basic, Digest).
# @param export_auth_passfile The apache htaccess file to use.
#
class aptly_profile(
  String               $aptly_user                = 'aptly',
  String               $aptly_uid                 = '401',
  String               $aptly_group               = 'users',
  String               $aptly_homedir             = '/data/aptly',
  String               $aptly_shell               = '/bin/bash',
  Hash                 $aptly_config              = {},
  Boolean              $manage_user               = true,
  Boolean              $manage_group              = true,
  Boolean              $manage_homedir            = true,
  Boolean              $manage_apache             = true,
  String               $cleanup_defaults          = '--keep 5 --days 3650 --package all --noop',
  String               $gpg_uid                   = 'Aptly repo server signing key',
  Boolean              $gpg_import_apt            = false,
  Optional[Stdlib::Absolutepath] $gpg_path        = undef,
  Hash                 $trusted_keys              = {},
  Hash                 $publish                   = {},
  Hash                 $mirrors                   = {},
  Hash                 $repos                     = {},
  Hash                 $mirror_defaults           = {},
  Hash                 $repo_defaults             = {},
  Hash                 $publish_defaults          = {},
  Array[String]        $aptly_environment         = [],
  Stdlib::Absolutepath $aptly_cache_dir           = '/var/cache/aptly',
  Boolean              $insert_hello              = true,
  Boolean              $enable_api                = false,
  Boolean              $proxy_api                 = true,
  Hash                 $proxy_api_htpasswd_users  = {},
  String               $api_vhost                 = "api.${facts['fqdn']}",
  String               $api_ensure                = 'running',
  String               $api_user                  = 'aptly',
  String               $api_group                 = 'users',
  Optional[String]     $api_listen_ip             = '127.0.0.1',
  Integer              $api_listen_port           = 8080,
  Boolean              $api_enable_cli_and_http   = true,
  Boolean              $force_https_reverse_proxy = true,
  Optional[Stdlib::Absolutepath] $export_auth_file = undef,
  Optional[String]     $export_auth_type          = 'basic',
  Optional[String]     $export_auth_passfile      = '/data/aptly/.aptly-passwdfile',
){

  $cleanup_script = "${aptly_homedir}/cleanup_repo.sh"
  $insert_hello_script = "${aptly_homedir}/insert_hello.sh"
  $api_listen = "${api_listen_ip}:${api_listen_port}"

  # These contain all the keywords to the different hashes that are
  # used in this profile (And not sent to upstream aptly)
  $_managed_repo_config_options = ['cleanup_options', 'allow_from']
  $_managed_publish_config_options = ['instant_publish', 'allow_from']

  # Deal with gpg... aptly still does not fully support gpg2.
  # And the internal go gpg implementation does not support the newer keyring
  # format.. Its a bit of a mess.
  # See:
  # * https://github.com/aptly-dev/aptly/issues/822
  # * https://github.com/golang/go/issues/29082
  # * https://www.gnupg.org/faq/whats-new-in-2.1.html#nosecring
  $real_gpg_path = $gpg_path ? {
    undef   => $facts['gpg_path'] ? {
      undef   => '/usr/bin/gpg',
      default => $facts['gpg_path'],
    },
    default => $gpg_path,
  }

  # User, group and homedir
  #########################
  if $manage_user {
    user {$aptly_user:
      ensure => present,
      gid    => $aptly_group,
      home   => $aptly_homedir,
      shell  => $aptly_shell,
      uid    => $aptly_uid,
    }
  }

  if $manage_group {
    group {$aptly_group:
      ensure => present,
    }
  }

  if $manage_homedir {
    file { $aptly_homedir:
      ensure  => 'directory',
      owner   => $aptly_user,
      group   => $aptly_group,
      require => User[$aptly_user],
    }
  }

  file { "${aptly_homedir}/public":
    ensure  => 'directory',
    owner   => $aptly_user,
    group   => $aptly_group,
    require => User[$aptly_user],
  }

  # Aptly itself
  ##############
  $_config = $aptly_config + { 'rootDir' => $aptly_homedir, }
  class { '::aptly':
    user          => $aptly_user,
    repo          => false, # don't include aptly.info repo
    config        => $_config,
    aptly_mirrors => {},
    require       => File[$aptly_homedir],
  }
  # ::aptly will read the mirrors to make from hiera
  # You will still need to manually update them (or wait for the cron below to
  # run

  $trusted_keys.each |$keyname, $keyconfig| {
    $gpg_and_config = $keyconfig + { 'gpg_path' => $real_gpg_path }
    ::aptly_profile::trusted_key {$keyname:
      * => $gpg_and_config,
    }
  }

  $_mirror_defaults = merge({'environment' => $aptly_environment}, $mirror_defaults)
  # Pass through the aptly_environment to the execs used for mirroring
  $mirrors.each |$mirror_name, $mirror_config| {
    ::aptly_profile::delayed_mirror {$mirror_name:
      config => $mirror_config,
    }
  }

  $cleanup_cronjob = "${aptly_homedir}/cron_cleanup_repo.sh"

  concat { $cleanup_cronjob:
    ensure => present,
    mode   => '0755',
  }

  concat::fragment { 'cron_cleanup_repo_header':
    target  => $cleanup_cronjob,
    order   => 0,
    content => '#!/bin/bash
#
# This file is managed by puppet and build from concat fragments in aptly_profile
#
',
  }

  # Filter out our cleanup options, which are used only for the cronjob and not the repo resource
  $repos.each |String $repo_name, Hash $repo_config| {

    $filtered_repo_config = $repo_config.filter |$pair| {
      !($pair[0] in $_managed_repo_config_options)
    }

    $cleanup_options = $repo_config.dig('cleanup_options') ? {
      undef   => $cleanup_defaults,
      default => $repo_config['cleanup_options'],
    }

    concat::fragment { "${repo_name}_cleanup":
      target  => $cleanup_cronjob,
      order   => 20,
      content => "${cleanup_script} --repo ${repo_name} ${cleanup_options}\n",
    }

    $combined_repo_config = merge($filtered_repo_config, $repo_defaults)
    # Create aptly repo
    ::aptly::repo { $repo_name:
      * => $combined_repo_config,
    }
    if $insert_hello {
      exec {"aptly_profile::insert_hello: ${repo_name}":
        command     => shell_join([
          $insert_hello_script, '--repo', $repo_name,
        ]),
        user        => $aptly_user,
        refreshonly => true,
        subscribe   => Exec["aptly_repo_create-${repo_name}"],
        require     => File[$insert_hello_script],
      }
    }
  }

  # Cronjob to cleanup repo
  cron { 'auto cleanup repos':
    user    => $aptly_user,
    hour    => '22',
    minute  => '15',
    command => "${cleanup_cronjob} | logger",
  }

  file { '/usr/bin/aptly-lock':
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/aptly_profile/aptly-lock',
  }

  # Automatic management (cron)
  #############################
  file { "${aptly_homedir}/aptly-update.rb":
    owner   => $aptly_user,
    group   => $aptly_group,
    mode    => '0755',
    source  => 'puppet:///modules/aptly_profile/aptly-update.rb',
    require => File[
      "${aptly_homedir}/aptly_update.rb",
      "${aptly_homedir}/aptly.rb",
      "${aptly_homedir}/indent_logger.rb",
      '/usr/bin/aptly-lock',
    ],
  }
  file { "${aptly_homedir}/aptly_update.rb":
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0644',
    source => 'puppet:///modules/aptly_profile/aptly_update.rb',
  }
  file { "${aptly_homedir}/aptly.rb":
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0644',
    source => 'puppet:///modules/aptly_profile/aptly.rb',
  }
  file { "${aptly_homedir}/indent_logger.rb":
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0644',
    source => 'puppet:///modules/aptly_profile/indent_logger.rb',
  }

  $publish_d = "${aptly_homedir}/publish.d"
  $mirror_d  = "${aptly_homedir}/mirror.d"

  file {[$publish_d, $mirror_d]:
    ensure => 'directory',
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0755',
    purge  => true,
  }

  file {["${publish_d}/00_CONTENTS_WARNING", "${mirror_d}/00_CONTENTS_WARNING"]:
    ensure => 'file',
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0644',
    source => 'puppet:///modules/aptly_profile/conf_d-header',
  }

  # cron with empty array keeps generating catalog changes
  $real_aptly_env =  empty($aptly_environment) ? {
    true    => undef,
    default => $aptly_environment,
  }

  cron { 'aptly-update':
    command     => "${aptly_homedir}/aptly-update.rb >/dev/null",
    user        => $aptly_user,
    require     => [
      User[$aptly_user],
      File["${aptly_homedir}/aptly-update.rb", $publish_d],
    ],
    hour        => 3,
    minute      => 17,
    environment => $real_aptly_env,
  }

  $publish.each |String $publish_name, Hash $config| {

    $filtered_publish_config = $config.filter |$pair| {
      !($pair[0] in $_managed_publish_config_options)
    }

    $instant_publish = $config.dig('instant_publish') ? {
      undef   => false,
      default => $config['instant_publish'],
    }

    aptly_profile::publish {$publish_name:
      config          => $config,
      instant_publish => $instant_publish,
    }

    $ifrepo = find_key($config, 'repo')
    if ($ifrepo != undef) {
      Aptly_profile::Publish[$publish_name] {
        require => Aptly::Repo[$ifrepo],
      }
    }
  }


  # Publishing
  ############
  if $manage_apache {
    class {'::aptly_profile::apache':
      docroot                   => "${aptly_homedir}/public",
      force_https_reverse_proxy => $force_https_reverse_proxy,
      enable_api                => $enable_api,
      api_vhost                 => $api_vhost,
      proxy_api                 => $proxy_api,
      api_listen                => $api_listen,
      proxy_api_htpasswd_users  => $proxy_api_htpasswd_users,
    }
  }

  # API
  #####
  if $enable_api {
    class { '::aptly::api':
      ensure              => $api_ensure,
      user                => $api_user,
      group               => $api_group,
      listen              => $api_listen,
      enable_cli_and_http => $api_enable_cli_and_http,
    }
  }

  if $export_auth_file {
    class {'::aptly_profile::auth':
      config_path => $export_auth_file,
      passfile    => $export_auth_passfile,
      repos       => $repos,
      publish     => $publish,
      require     => Class['apache'],
    }
  }

  # Cleanup script
  ################
  file { $cleanup_script:
    ensure => file,
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0755',
    source => 'puppet:///modules/aptly_profile/cleanup_repo.sh',
  }

  # aptly cache dir
  file {$aptly_cache_dir:
    ensure => 'directory',
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0750',
  }

  # Insert hello package script
  #############################
  file {$insert_hello_script:
    ensure => 'file',
    owner  => $aptly_user,
    group  => $aptly_group,
    mode   => '0750',
    source => 'puppet:///modules/aptly_profile/initialize_hello_repository.sh',
  }

  # Repo Singing Key management
  #############################

  # Mostly copy-paste from `keypair::gpg_keypair`
  # We can't use the `keypair::gpg_keypair` defined type, because we need access
  # to the $key variable to create our `apt::key` resource

  file { "${aptly_homedir}/gpg_keys":
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  ensure_resource('file', '/etc/gpg_keys', { 'ensure' => 'directory' })

  $basename = "${aptly_homedir}/gpg_keys/aptly"

  $existing_key = keypair::get_first_matching_value($::gpg_keys, {
      'secret_present' => true,
      'basename'       => 'aptly',
  })

  if $existing_key {
    $key = $existing_key
    file { "${basename}.sec":
      ensure  => file,
      owner   => $aptly_user,
      group   => 'root',
      mode    => '0400',
      content => undef,
    }
  } else { # no existing key
    $generated_key = gpg_generate_key({
        'uid' => $gpg_uid,
    })
    $key = $generated_key

    file { "${basename}.sec":
      ensure  => file,
      owner   => $aptly_user,
      group   => 'root',
      mode    => '0400',
      content => $generated_key['secret_key'],
    }
  }

  file { "${basename}.pub":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => $key['public_key'],
  }

  file { '/etc/gpg_keys/aptly.pub':
    ensure => link,
    target =>  "${basename}.pub",
  }

  file { '/etc/gpg_keys/aptly.sec':
    ensure => link,
    target =>  "${basename}.sec",
  }

  @@::apt::key { "aptly key ${::hostname}":
    id      => $key['fingerprint'],
    content => $key['public_key'],
    tag     => $facts['fqdn'],
  }

  if $gpg_import_apt {
    ::apt::key { "aptly key ${::hostname}-local":
      id      => $key['fingerprint'],
      content => $key['public_key'],
    }
  }

  # Aptly expects the signing key to be in its GnuPG keyring
  # Import/replace it
  exec { 'aptly_profile::init import aptly GPG key in to keyring':
    user        => $aptly_user,
    environment => ["HOME=${aptly_homedir}"],
    cwd         => $aptly_homedir,
    unless      => "${real_gpg_path} --list-secret-keys ${key['fingerprint']}",
    command     => "${real_gpg_path} --import '${basename}.sec'",
  }
  exec { 'aptly_profile::init update aptly GPG key in keyring':
    refreshonly => true,
    subscribe   => File["${basename}.sec"],
    user        => $aptly_user,
    environment => ["HOME=${aptly_homedir}"],
    cwd         => $aptly_homedir,
    command     => "/bin/rm -rf .gnupg; ${real_gpg_path} --import '${basename}.sec'",
  }

}
