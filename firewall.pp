class my_fw {
    #include my_fw::flush

    Firewall {
        require => Class['my_fw::pre'],
    }
    class { ['my_fw::pre', 'my_fw::post']: }
    class { 'firewall': }

  firewall { '003 accept SSH':
    port   => 22,
    proto  => tcp,
    action => accept,
  }
  firewall { '004 accept Nginx 8000':
    port   => 8000,
    proto  => tcp,
    action => accept,
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
}
class my_fw::post {
  exec { "iptables_input_set_default":
    command => "iptables -P INPUT DROP",
    path    => "/usr/local/bin/:/bin/:/usr/bin/:/usr/sbin/:/sbin/",
  }   
}