# == Class: zookeeper::config
#
# Zookeeper configuration.
#
class zookeeper::config {
  if $zookeeper::hostnames {
    $myid = array_search($zookeeper::hostnames, $::fqdn)
  } else {
    $myid = undef
  }
  notice("myid: ${myid}")

  if !$myid {
    notice("Missing myid! Zookeeper server ${::fqdn} not in zookeeper::hostnames list.")
  }

  file { "${zookeeper::confdir}/zoo.cfg":
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('zookeeper/zoo.cfg.erb'),
    alias   => 'zoo-cfg',
  }

  $keytab = '/etc/security/keytab/zookeeper.service.keytab'
  $principal = "zookeeper/${::fqdn}@${zookeeper::realm}"

  if $zookeeper::realm {
    file { $keytab:
      owner => 'zookeeper',
      group => 'zookeeper',
      mode  => '0400',
    }

    file { "${zookeeper::confdir}/jaas.conf":
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('zookeeper/jaas.conf.erb'),
    }
  } else {
    file { "${zookeeper::confdir}/jaas.conf":
      ensure => 'absent',
    }
  }

  if $zookeeper::_properties {
    file { "${zookeeper::confdir}/java.env":
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('zookeeper/java.env.erb'),
    }
  } else {
    file { "${zookeeper::confdir}/java.env":
      ensure => 'absent',
    }
  }

  case $::osfamily {
    'RedHat',default: {
      if $myid {
        file { "${zookeeper::datadir}/myid":
          owner   => 'zookeeper',
          group   => 'zookeeper',
          mode    => '0644',
          replace => false,
          content => $myid,
        }
      }
    }
    'Debian': {
      if $myid {
        $args = "--myid ${myid}"
      } else {
        $args = ''
      }
      exec { 'zookeeper-init':
        command => "zookeeper-server-initialize ${args}",
        creates => "${zookeeper::datadir}/version-2",
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        user    => 'zookeeper',
        require => [ File['zoo-cfg'], ],
      }
      if $zookeeper::realm {
        File[$keytab] -> Exec['zookeeper-init']
        File["${zookeeper::confdir}/jaas.conf"] -> Exec['zookeeper-init']
        File["${zookeeper::confdir}/java.env"] -> Exec['zookeeper-init']
      }
    }
  }
}
