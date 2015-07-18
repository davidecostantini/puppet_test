Package {
   allow_virtual => false
}

class my_fw {
    #include my_fw::flush

    Firewall {
        before  => Class['my_fw::post'],
        require => Class['my_fw::pre'],
    }
    class { ['my_fw::pre', 'my_fw::post']: }
    class { 'firewall': }

    include my_fw::webserver
}


class my_fw::webserver {
  firewall { '008 Allow inbound SSH':
    port     => 22,
    proto    => tcp,
    action   => accept,
  }
  firewall { '009 Allow Nginx 8000':
    port     => 8000,
    proto    => tcp,
    action   => accept,
  }  
}

class my_fw::pre {
  Firewall {
    require => undef,
  }

  # Default firewall rules
  firewall { '000 accept all icmp':
    proto   => 'icmp',
    action  => 'accept',
  }->
  firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }->
  firewall { '002 accept related established rules':
    proto   => 'all',
    state => ['RELATED', 'ESTABLISHED'],
    action  => 'accept',
  }

  #-----------------------------------
}
class my_fw::post {
  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    policy => drop,
    before => undef,
  }
  firewallchain { 'FORWARD:filter:IPv4':
    ensure => present,
    policy => drop,
    before => undef,
  }
}

node default {
        include git

		$nginx_data = $osfamily ? {
		    /(Debian|Ubuntu)/ => 'www-data',
		    default            => 'nginx',
		}
        class { 'nginx': }

        case $operatingsystem {
              'RedHat', 'CentOS': { class { selinux: mode => 'permissive' }
            }
        }    

        include my_fw

	    vcsrepo { '/var/www/demo':
			ensure   => latest,
			provider => git,
			source   => 'https://github.com/puppetlabs/exercise-webpage.git',
			revision => 'master',
			notify => Service['nginx'],
        }

        file { '/var/www':
			ensure  => directory,
			recurse => true,
			owner => $nginx_data,
			group => $nginx_data,
			mode => 0500,
			require   => Vcsrepo['/var/www/demo'],
        }

        nginx::resource::vhost { '_':
			www_root => '/var/www/demo',
			listen_port => 8000,
        }        
}
