require 'shellwords'

module MongoDBCookbook
  module Helpers
    include Chef::DSL::IncludeRecipe

    def base_dir
      prefix_dir || '/usr'
    end

    def configure_package_repositories
      # TODO: we need to enable the mongodb-community repository to get packages
      
    end

    def client_package_name
      return new_resource.package_name if new_resource.package_name
      client_package
    end

    def defaults_file
      "#{etc_dir}/mongodb.conf"
    end

    def error_log
      return new_resource.error_log if new_resource.error_log
      "#{log_dir}/error.log"
    end

    def etc_dir
      return "/opt/mongodb#{pkg_ver_string}/etc/#{mongodb_name}" if node['platform_family'] == 'omnios'
      return "#{prefix_dir}/etc/#{mongodb_name}" if node['platform_family'] == 'smartos'
      "#{prefix_dir}/etc/#{mongodb_name}"
    end

    def include_dir
      "#{etc_dir}/conf.d"
    end

    def lc_messages_dir
    end

    def log_dir
      return "/var/adm/log/#{mongodb_name}" if node['platform_family'] == 'omnios'
      "#{prefix_dir}/var/log/#{mongodb_name}"
    end

    def mongodb_name
      "mongodb-#{new_resource.instance}"
    end

    def pkg_ver_string
      parsed_version.delete('.') if node['platform_family'] == 'omnios'
    end

    def prefix_dir
      return "/opt/mongodb#{pkg_ver_string}" if node['platform_family'] == 'omnios'
      return '/opt/local' if node['platform_family'] == 'smartos'
      return "/opt/rh/#{scl_name}/root" if scl_package?
    end

    def scl_name
      return unless node['platform_family'] == 'rhel'
      return 'mongodb51' if parsed_version == '5.1' && node['platform_version'].to_i == 5
      return 'mongodb55' if parsed_version == '5.5' && node['platform_version'].to_i == 5
    end

    def scl_package?
      return unless node['platform_family'] == 'rhel'
      return true if parsed_version == '5.1' && node['platform_version'].to_i == 5
      return true if parsed_version == '5.5' && node['platform_version'].to_i == 5
      false
    end

    def system_service_name
      return 'mongodb51-mongodbd' if node['platform_family'] == 'rhel' && scl_name == 'mongodb51'
      return 'mongodb55-mongodbd' if node['platform_family'] == 'rhel' && scl_name == 'mongodb55'
      return 'mongodbd' if node['platform_family'] == 'rhel'
      return 'mongodbd' if node['platform_family'] == 'fedora'
      return 'mongodb' if node['platform_family'] == 'debian'
      return 'mongodb' if node['platform_family'] == 'suse'
      return 'mongodb' if node['platform_family'] == 'omnios'
      return 'mongodb' if node['platform_family'] == 'smartos'
    end

    def v56plus
      return false if parsed_version.split('.')[0].to_i < 5
      return false if parsed_version.split('.')[1].to_i < 6
      true
    end

    def v57plus
      return false if parsed_version.split('.')[0].to_i < 5
      return false if parsed_version.split('.')[1].to_i < 7
      true
    end

    def password_column_name
      return 'authentication_string' if v57plus
      'password'
    end

    def password_expired
      return ", password_expired='N'" if v57plus
      ''
    end

    def root_password
      if new_resource.initial_root_password == ''
        Chef::Log.info('Root password is empty')
        return ''
      end
      Shellwords.escape(new_resource.initial_root_password)
    end

    # database and initial records
    # initialization commands

    def mongodbd_initialize_cmd
      cmd = mongodbd_bin
      cmd << " --defaults-file=#{etc_dir}/my.cnf"
      cmd << ' --initialize'
      cmd << ' --explicit_defaults_for_timestamp' if v56plus
      return "scl enable #{scl_name} \"#{cmd}\"" if scl_package?
      cmd
    end

    def mongodb_install_db_cmd
      cmd = mongodb_install_db_bin
      cmd << " --defaults-file=#{etc_dir}/my.cnf"
      cmd << " --datadir=#{parsed_data_dir}"
      cmd << ' --explicit_defaults_for_timestamp' if v56plus
      return "scl enable #{scl_name} \"#{cmd}\"" if scl_package?
      cmd
    end

    def record_init
      cmd = v56plus ? mongodbd_bin : mongodbd_safe_bin
      cmd << " --defaults-file=#{etc_dir}/my.cnf"
      cmd << " --init-file=/tmp/#{mongodb_name}/my.sql"
      cmd << ' --explicit_defaults_for_timestamp' if v56plus
      cmd << ' &'
      return "scl enable #{scl_name} \"#{cmd}\"" if scl_package?
      cmd
    end

    def db_init
      return mongodbd_initialize_cmd if v57plus
      mongodb_install_db_cmd
    end

    def init_records_script
      <<-EOS
        set -e
        rm -rf /tmp/#{mongodb_name}
        mkdir /tmp/#{mongodb_name}

        cat > /tmp/#{mongodb_name}/my.sql <<-EOSQL
UPDATE mongodb.user SET #{password_column_name}=PASSWORD('#{root_password}')#{password_expired} WHERE user = 'root';
DELETE FROM mongodb.user WHERE USER LIKE '';
DELETE FROM mongodb.user WHERE user = 'root' and host NOT IN ('127.0.0.1', 'localhost');
FLUSH PRIVILEGES;
DELETE FROM mongodb.db WHERE db LIKE 'test%';
DROP DATABASE IF EXISTS test ;
EOSQL

       #{db_init}
       #{record_init}

       while [ ! -f #{pid_file} ] ; do sleep 1 ; done
       kill `cat #{pid_file}`
       while [ -f #{pid_file} ] ; do sleep 1 ; done
       rm -rf /tmp/#{mongodb_name}
       EOS
    end

    def mongodb_bin
      return "#{prefix_dir}/bin/mongodb" if node['platform_family'] == 'smartos'
      return "#{base_dir}/bin/mongodb" if node['platform_family'] == 'omnios'
      "#{prefix_dir}/usr/bin/mongodb"
    end

    def mongodb_install_db_bin
      return "#{base_dir}/scripts/mongodb_install_db" if node['platform_family'] == 'omnios'
      return "#{prefix_dir}/bin/mongodb_install_db" if node['platform_family'] == 'smartos'
      'mongodb_install_db'
    end

    def mongodb_version
      new_resource.version
    end

    def mongodbadmin_bin
      return "#{prefix_dir}/bin/mongodbadmin" if node['platform_family'] == 'smartos'
      return 'mongodbadmin' if scl_package?
      "#{prefix_dir}/usr/bin/mongodbadmin"
    end

    def mongodbd_bin
      return "#{prefix_dir}/libexec/mongodbd" if node['platform_family'] == 'smartos'
      return "#{base_dir}/bin/mongodbd" if node['platform_family'] == 'omnios'
      return '/usr/sbin/mongodbd' if node['platform_family'] == 'fedora' && v56plus
      return '/usr/libexec/mongodbd' if node['platform_family'] == 'fedora'
      return 'mongodbd' if scl_package?
      "#{prefix_dir}/usr/sbin/mongodbd"
    end

    def mongodbd_safe_bin
      return "#{prefix_dir}/bin/mongodbd_safe" if node['platform_family'] == 'smartos'
      return "#{base_dir}/bin/mongodbd_safe" if node['platform_family'] == 'omnios'
      return 'mongodbd_safe' if scl_package?
      "#{prefix_dir}/usr/bin/mongodbd_safe"
    end

    def pid_file
      return new_resource.pid_file if new_resource.pid_file
      "#{run_dir}/mongodbd.pid"
    end

    def run_dir
      return "#{prefix_dir}/var/run/#{mongodb_name}" if node['platform_family'] == 'rhel'
      return "/run/#{mongodb_name}" if node['platform_family'] == 'debian'
      "/var/run/#{mongodb_name}"
    end

    def sensitive_supported?
      Gem::Version.new(Chef::VERSION) >= Gem::Version.new('11.14.0')
    end

    def socket_file
      return new_resource.socket if new_resource.socket
      "#{run_dir}/mongodbd.sock"
    end

    def socket_dir
      return File.dirname(new_resource.socket) if new_resource.socket
      run_dir
    end

    def tmp_dir
      return new_resource.tmp_dir if new_resource.tmp_dir
      '/tmp'
    end

    #######
    # FIXME: There is a LOT of duplication here..
    # There has to be a less gnarly way to look up this information. Refactor for great good!
    #######
    class Pkginfo
      def self.pkginfo
        # Autovivification is Perl.
        @pkginfo = Chef::Node.new

        @pkginfo.set['debian']['10.04']['5.1']['client_package'] = %w(mongodb-client-5.1 libMongoDBInstance-dev)
        @pkginfo.set['debian']['10.04']['5.1']['server_package'] = 'mongodb-server-5.1'
        @pkginfo.set['debian']['12.04']['5.5']['client_package'] = %w(mongodb-client-5.5 libMongoDBInstance-dev)
        @pkginfo.set['debian']['12.04']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['13.04']['5.5']['client_package'] = %w(mongodb-client-5.5 libMongoDBInstance-dev)
        @pkginfo.set['debian']['13.04']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['13.10']['5.5']['client_package'] = %w(mongodb-client-5.5 libMongoDBInstance-dev)
        @pkginfo.set['debian']['13.10']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['14.04']['5.5']['client_package'] = %w(mongodb-client-5.5 libMongoDBInstance-dev)
        @pkginfo.set['debian']['14.04']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['14.04']['5.6']['client_package'] = %w(mongodb-client-5.6 libMongoDBInstance-dev)
        @pkginfo.set['debian']['14.04']['5.6']['server_package'] = 'mongodb-server-5.6'
        @pkginfo.set['debian']['14.10']['5.5']['client_package'] = %w(mongodb-client-5.5 libMongoDBInstance-dev)
        @pkginfo.set['debian']['14.10']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['14.10']['5.6']['client_package'] = %w(mongodb-client-5.6 libMongoDBInstance-dev)
        @pkginfo.set['debian']['14.10']['5.6']['server_package'] = 'mongodb-server-5.6'
        @pkginfo.set['debian']['15.04']['5.6']['client_package'] = %w(mongodb-client-5.6 libMongoDBInstance-dev)
        @pkginfo.set['debian']['15.04']['5.6']['server_package'] = 'mongodb-server-5.6'
        @pkginfo.set['debian']['6']['5.1']['client_package'] = %w(mongodb-client libMongoDBInstance-dev)
        @pkginfo.set['debian']['6']['5.1']['server_package'] = 'mongodb-server-5.1'
        @pkginfo.set['debian']['7']['5.5']['client_package'] = %w(mongodb-client libMongoDBInstance-dev)
        @pkginfo.set['debian']['7']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['debian']['7']['5.6']['client_package'] = %w(mongodb-client libMongoDBInstance-dev) # apt-repo from dotdeb
        @pkginfo.set['debian']['7']['5.6']['server_package'] = 'mongodb-server-5.6'
        @pkginfo.set['debian']['7']['5.7']['client_package'] = %w(mongodb-client libMongoDBInstance-dev) # apt-repo from dotdeb
        @pkginfo.set['debian']['7']['5.7']['server_package'] = 'mongodb-server-5.7'
        @pkginfo.set['debian']['8']['5.5']['client_package'] = %w(mongodb-client libMongoDBInstance-dev)
        @pkginfo.set['debian']['8']['5.5']['server_package'] = 'mongodb-server-5.5'
        @pkginfo.set['fedora']['20']['5.5']['client_package'] = %w(community-mongodb community-mongodb-devel)
        @pkginfo.set['fedora']['20']['5.5']['server_package'] = 'community-mongodb-server'
        @pkginfo.set['fedora']['20']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['20']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['fedora']['20']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['20']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['fedora']['21']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['21']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['fedora']['21']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['21']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['fedora']['22']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['22']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['fedora']['22']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['fedora']['22']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['freebsd']['10']['5.5']['client_package'] = %w(mongodb55-client)
        @pkginfo.set['freebsd']['10']['5.5']['server_package'] = 'mongodb55-server'
        @pkginfo.set['freebsd']['9']['5.5']['client_package'] = %w(mongodb55-client)
        @pkginfo.set['freebsd']['9']['5.5']['server_package'] = 'mongodb55-server'
        @pkginfo.set['omnios']['151006']['5.5']['client_package'] = %w(database/mongodb-55/library)
        @pkginfo.set['omnios']['151006']['5.5']['server_package'] = 'database/mongodb-55'
        @pkginfo.set['omnios']['151006']['5.6']['client_package'] = %w(database/mongodb-56)
        @pkginfo.set['omnios']['151006']['5.6']['server_package'] = 'database/mongodb-56'
        @pkginfo.set['rhel']['2014.09']['5.1']['server_package'] = %w(mongodb51 mongodb51-devel)
        @pkginfo.set['rhel']['2014.09']['5.1']['server_package'] = 'mongodb51-server'
        @pkginfo.set['rhel']['2014.09']['5.5']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2014.09']['5.5']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2014.09']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2014.09']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2014.09']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2014.09']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.03']['5.1']['server_package'] = %w(mongodb51 mongodb51-devel)
        @pkginfo.set['rhel']['2015.03']['5.1']['server_package'] = 'mongodb51-server'
        @pkginfo.set['rhel']['2015.03']['5.5']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.03']['5.5']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.03']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.03']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.03']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.03']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.09']['5.1']['server_package'] = %w(mongodb51 mongodb51-devel)
        @pkginfo.set['rhel']['2015.09']['5.1']['server_package'] = 'mongodb51-server'
        @pkginfo.set['rhel']['2015.09']['5.5']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.09']['5.5']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.09']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.09']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['2015.09']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['2015.09']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['5']['5.0']['client_package'] = %w(mongodb mongodb-devel)
        @pkginfo.set['rhel']['5']['5.0']['server_package'] = 'mongodb-server'
        @pkginfo.set['rhel']['5']['5.1']['client_package'] = %w(mongodb51-mongodb)
        @pkginfo.set['rhel']['5']['5.1']['server_package'] = 'mongodb51-mongodb-server'
        @pkginfo.set['rhel']['5']['5.5']['client_package'] = %w(mongodb55-mongodb mongodb55-mongodb-devel)
        @pkginfo.set['rhel']['5']['5.5']['server_package'] = 'mongodb55-mongodb-server'
        @pkginfo.set['rhel']['5']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['5']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['5']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['5']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['6']['5.1']['client_package'] = %w(mongodb mongodb-devel)
        @pkginfo.set['rhel']['6']['5.1']['server_package'] = 'mongodb-server'
        @pkginfo.set['rhel']['6']['5.5']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['6']['5.5']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['6']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['6']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['6']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['6']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['7']['5.5']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['7']['5.5']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['7']['5.6']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['7']['5.6']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['rhel']['7']['5.7']['client_package'] = %w(mongodb-community-client mongodb-community-devel)
        @pkginfo.set['rhel']['7']['5.7']['server_package'] = 'mongodb-community-server'
        @pkginfo.set['smartos']['5.11']['5.5']['client_package'] = %w(mongodb-client)
        @pkginfo.set['smartos']['5.11']['5.5']['server_package'] = 'mongodb-server'
        @pkginfo.set['smartos']['5.11']['5.6']['client_package'] = %w(mongodb-client)
        @pkginfo.set['smartos']['5.11']['5.6']['server_package'] = 'mongodb-server'
        @pkginfo.set['suse']['11.3']['5.5']['client_package'] = %w(mongodb-client)
        @pkginfo.set['suse']['11.3']['5.5']['server_package'] = 'mongodb'
        @pkginfo.set['suse']['12.0']['5.5']['client_package'] = %w(mongodb-client)
        @pkginfo.set['suse']['12.0']['5.5']['server_package'] = 'mongodb'

        @pkginfo
      end
    end

    def package_name_for(platform, platform_family, platform_version, version, type)
      keyname = keyname_for(platform, platform_family, platform_version)
      info = Pkginfo.pkginfo[platform_family.to_sym][keyname]
      type_label = type.to_s.gsub('_package', '').capitalize
      unless info[version]
        # Show availabe versions if the requested is not available on the current platform
        Chef::Log.error("Unsupported Version: You requested to install a mongodb #{type_label} version that is not supported by your platform")
        Chef::Log.error("Platform: #{platform_family} #{platform_version} - Request mongodb #{type_label} version: #{version}")
        Chef::Log.error("Availabe versions for your platform are: #{info.map { |k, _v| k }.join(' - ')}")
        fail "Unsupported mongodb #{type_label} Version"
      end
      info[version][type]
    end

    def keyname_for(platform, platform_family, platform_version)
      return platform_version if platform_family == 'debian' && platform == 'ubuntu'
      return platform_version if platform_family == 'fedora'
      return platform_version if platform_family == 'omnios'
      return platform_version if platform_family == 'rhel' && platform == 'amazon'
      return platform_version if platform_family == 'smartos'
      return platform_version if platform_family == 'suse'
      return platform_version.to_i.to_s if platform_family == 'debian'
      return platform_version.to_i.to_s if platform_family == 'rhel'
      return platform_version.to_s if platform_family == 'debian' && platform_version =~ /sid$/
      return platform_version.to_s if platform_family == 'freebsd'
    end

    def parsed_data_dir
      return new_resource.data_dir if new_resource.data_dir
      return "/opt/local/lib/#{mongodb_name}" if node['os'] == 'solaris2'
      return "/var/lib/#{mongodb_name}" if node['os'] == 'linux'
      return "/var/db/#{mongodb_name}" if node['os'] == 'freebsd'
    end

    def client_package
      package_name_for(
        node['platform'],
        node['platform_family'],
        node['platform_version'],
        parsed_version,
        :client_package
      )
    end

    def server_package
      package_name_for(
        node['platform'],
        node['platform_family'],
        node['platform_version'],
        parsed_version,
        :server_package
      )
    end

    def server_package_name
      return new_resource.package_name if new_resource.package_name
      server_package
    end
  end
end