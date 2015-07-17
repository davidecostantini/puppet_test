Package {
   allow_virtual => false
}


node default {
	include git

	class { 'nginx': }

	case $operatingsystem {
	      'RedHat', 'CentOS': {	class { selinux: mode => 'permissive' }
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

	nginx::resource::vhost { '_':
	  www_root => '/var/www/demo',
	  listen_port => 8000,
	}
}