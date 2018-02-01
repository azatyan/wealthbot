
# usage:
#
#  beanstalkd::config { name:
#    listenaddress  => '0.0.0.0',
#    listenport     => '13000',
#    maxjobsize     => '65535',
#    maxconnections => '1024',
#    binlogdir      => '/var/lib/beanstalkd/binlog',
#    binlogfsync    => undef,
#    binlogsize     => '10485760',
#    ensure         => 'running',   # running, stopped, absent
#    packageversion => 'latest',    # latest, present, or specific version
#    packagename    => undef,       # override package name
#    servicename    => undef        # override service name
#  }


define beanstalkd::config ( # name
  $listenaddress  = '0.0.0.0',
  $listenport     = '13000',
  $maxjobsize     = '65535',
  $maxconnections = '1024',                       # results in open file limit
  $binlogdir      = '/var/lib/beanstalkd/binlog', # set empty ( '' ) to disable binlog
  $binlogfsync    = undef,                        # unset = no explicit fsync
  $binlogsize     = '10485760',
  #
  $ensure         = 'running',  # running, stopped, absent
  $packageversion = 'latest',   # latest, present, or specific version
  $packagename    = undef,      # got your own custom package?  override the default name/service here.
  $servicename    = undef
) {

  case $::operatingsystem {
    debian, ubuntu: {
      $defaultpackagename = 'beanstalkd'
      $defaultservicename = 'beanstalkd'
      $user               = 'beanstalkd'
      $configfile         = '/etc/init.d/beanstalkd'
      $configtemplate     = "${module_name}/debian/beanstalkd.erb"
      $hasstatus          = 'true'
      $restart            = '/etc/init.d/beanstalkd restart'
      $mode               = '0755'
    }
    centos, redhat: {
      $defaultpackagename = 'beanstalkd'
      $defaultservicename = 'beanstalkd'
      $user               = 'beanstalkd'
      $configfile         = '/etc/sysconfig/beanstalkd'
      $configtemplate     = "${module_name}/redhat/beanstalkd_sysconfig.erb"
      $hasstatus          = 'true'
      $restart            = '/etc/init.d/beanstalkd restart'
      $mode               = '0644'
    }
    # TODO: add more OS support!
    default: {
      fail("ERROR [${module_name}]: I don't know how to manage this OS: ${::operatingsystem}")
    }
  }

  # simply the users experience for running/stopped/absent, and use ensure to cover those bases
  case $ensure {
    absent: {
      $ourpackageversion  = 'absent'
      $serviceenable      = 'false'
      $serviceensure      = 'stopped'
      $fileensure         = 'absent'
    }
    running: {
      $ourpackageversion = $packageversion
      $serviceenable     = 'true'
      $serviceensure     = 'running'
      $fileensure        = 'present'
    }
    stopped: {
      $ourpackageversion = $packageversion
      $serviceenable     = 'false'
      $serviceensure     = 'stopped'
      $fileensure        = 'present'
    }
    default: {
      fail("ERROR [${module_name}]: enable must be one of: running stopped absent")
    }
  }

  # for service and package name - if we've specified one, use it. else use the default
  if $packagename == undef {
    $ourpackagename = $defaultpackagename
  } else {
    $ourpackagename = $packagename
  }

  if $servicename == undef {
    $ourservicename = $defaultservicename
  } else {
    $ourservicename = $servicename
  }

  package { $ourpackagename:
    ensure => $ourpackageversion
  }

  file { $configfile:
    content => template($configtemplate),
    owner   => 'root',
    group   => 'root',
    mode    => $mode,
    ensure  => $fileensure,
    require => Package[$ourpackagename],
  }

  service { $ourservicename:
    enable    => $serviceenable,
    ensure    => $serviceensure,
    hasstatus => $hasstatus,
    restart   => $restart,
    require   => File[$configfile],
    subscribe => [
      Package[$ourpackagename],
      File[$configfile]
    ],
  }

}
