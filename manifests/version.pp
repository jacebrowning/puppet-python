# Install a Python version via pyenv
#
# Usage:
#
#   python::version { '2.7.3': }
#

define python::version(
  $ensure  = 'installed',
  $env     = {},
  $version = $name,
) {
  require python

  $alias_hash = hiera_hash('python::version::alias', {})
  $dest = "/opt/python/${version}"

  if has_key($alias_hash, $version) {
    $to = $alias_hash[$version]

    python::alias { $version:
      ensure => $ensure,
      to     => $to,
    }
  } elsif $ensure == 'absent' {
    file { $dest:
      ensure => absent,
      force  => true,
    }
  } else {
    case $version {
      /jython/: { require java }
      default: { }
    }

    $default_env = {
      'CC'         => '/usr/bin/cc',
      'PYENV_ROOT' => $python::pyenv::prefix,
    }

    if $::operatingsystem == 'Darwin' {
      require xquartz
      include homebrew::config
      include boxen::config
      ensure_resource('package', 'readline')
    }

    $hierdata = hiera_hash('python::version::env', {})

    if has_key($hierdata, $::operatingsystem) {
      $os_env = $hierdata[$::operatingsystem]
    } elsif $::operatingsystem == 'Darwin' {
      $os_env = {'PYTHON_CONFIGURE_OPTS' => '--enable-framework'}
    } else {
      $os_env = {'PYTHON_CONFIGURE_OPTS' => '--enable-shared'}
    }

    if has_key($hierdata, $version) {
      $version_env = $hierdata[$version]
    } else {
      $version_env = {}
    }

    notice($_env)
    $_env = {'PYTHON_CONFIGURE_OPTS' => '--enable-framework'}
    notice($_env)
    $_env = merge(merge(merge($default_env, $os_env), $version_env), $env)

    if has_key($_env, 'CC') and $_env['CC'] =~ /gcc/ {
      require gcc
    }

    exec { "python-install-${version}":
      command     => "${python::pyenv::prefix}/bin/pyenv install --skip-existing ${version}",
      cwd         => "${python::pyenv::prefix}/versions",
      provider    => 'shell',
      timeout     => 0,
      creates     => $dest,
      user        => $python::pyenv::user,
      require     => Package['readline'],
    }

    Exec["python-install-${version}"] {
      environment +> sort(join_keys_to_values($_env, '='))
    }
  }
}
