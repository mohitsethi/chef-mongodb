#
# Cookbook Name:: mongo
# Provider:: db
#
# Copyright 2015, Mohit Sethi <mohit@sethis.in>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

def whyrun_supported?
  true
end

action :remove do
  service new_resource.name do
    action [:stop, :disable]
  end

  directory "#{new_resource.home}/mongodb-#{new_resource.name}" do
    action :delete
    recursive true
  end

  file "/etc/init.d/mongodb-#{new_resource.name}" do
    action :delete
  end

  file "/etc/logrotate.d/mongodb-#{new_resource.name}-logs" do
    action :delete
  end

  cron_d "mongodb-#{new_resource.name}-monitoring" do
    action :delete
  end

  file "/tmp/mongodb-monitoring-status-#{new_resource.port}" do
    action :delete
  end
end

action :create do
  Chef::Log.info("MongoDB binary: #{new_resource.name}")

  base = "#{new_resource.home}/mongodb-#{new_resource.name}"

  group "#{new_resource.user}" do
    action :create
    system true
  end

  user "#{new_resource.group}" do
    gid "#{new_resource.group}"
    shell '/bin/false'
    home '/tmp'
    system true
    action :create
    only_if do
      ::File.readlines('/etc/passwd').grep(/^mongodb/).size <= 0
    end
  end

  directory base do
    owner "#{new_resource.user}"
    group "#{new_resource.group}"
    mode '0755'
    action :create
    recursive true
  end

  %w( etc data log var ).each do |dirname|
    directory "#{base}/#{dirname}" do
      owner "#{new_resource.user}"
      group "#{new_resource.group}"
      mode '0750'
      action :create
      recursive false
    end
  end

  t = template "#{base}/etc/mongodb.conf" do
    source 'etc/mongodb.conf.erb'
<<<<<<< HEAD:providers/instance.rb
    cookbook 'MongoDB'
    owner 'root'
    group 'root'
=======
    cookbook 'L7-mongo'
    owner "#{new_resource.user}"
    group "#{new_resource.group}"
>>>>>>> fd9e26a... make user, group parameterized thru LWRP:providers/db.rb
    mode '0644'
    variables(
      name: new_resource.name,
      port: new_resource.port,
      bind_ip: new_resource.bind_ip,
      socket: base + '/var',
      pidfile: base + '/var/mongodb.pid',
      log: base + '/log/mongodb.log',
      datadir: base + '/data',
      replSet: new_resource.replSet,
      notablescan: new_resource.notablescan,
      smallfiles: new_resource.smallfiles,
      journal: new_resource.journal,
      rest: new_resource.rest,
      httpinterface: new_resource.httpinterface,
      auth: new_resource.auth
    )
  end
  new_resource.updated_by_last_action(t.updated_by_last_action?)

  if new_resource.rest
    cron_d "mongodb-#{new_resource.name}-monitoring" do
      hour '*'
      minute '*'
      day '*'
      month '*'
      weekday '*'
      command "if timeout 3 /usr/bin/wget --timeout=15 --tries=2 --quiet \
-O /tmp/mongodb-monitoring-status-#{new_resource.port}.tmp \
http://127.0.0.1:#{new_resource.port.to_i + 1000}/_status &> /dev/null; \
then \
sleep 1; mv /tmp/mongodb-monitoring-status-#{new_resource.port}.tmp \
/tmp/mongodb-monitoring-status-#{new_resource.port}; \
else \
rm -f /tmp/mongodb-monitoring-status-#{new_resource.port}.tmp; fi"
      user 'root'
      shell '/bin/bash'
    end
  else
    cron_d "mongodb-#{new_resource.name}-monitoring" do
      action :delete
    end

    file "/tmp/mongodb-monitoring-status-#{new_resource.port}" do
      action :delete
    end
  end

  %w( wget numactl ).each do |pkg|
    package pkg do
      action :install
    end
  end

  filename = ::File.basename(new_resource.url)
  dirname = filename.sub(/(\.tar\.gz$|\.tgz$)/, '')

  bash 'get_mongodb_binary' do
    user 'root'
    cwd base
    code <<-EOH
    wget --no-check-certificate #{new_resource.url}
    tar -zxf #{filename}
    EOH
    not_if do
      ::File.exist?(base + '/' + filename)
    end
  end

  link "#{base}/current" do
    to "#{base}/#{dirname}"
    link_type :symbolic
  end

  t = template "/etc/init.d/mongodb-#{new_resource.name}" do
    source 'etc/init.d/mongodb-init.erb'
    cookbook 'MongoDB'
    owner 'root'
    group 'root'
    mode '0755'
    variables(
      daemon: "#{base}/current/bin/mongod",
      datadir: "#{base}/data",
      config: "#{base}/etc/mongodb.conf",
      name: "mongodb-#{new_resource.name}",
      pid: "#{base}/var/mongodb.pid"
    )
  end
  new_resource.updated_by_last_action(t.updated_by_last_action?)

  service "mongodb-#{new_resource.name}" do
    action :enable
    supports status: true, restart: true
  end

  t = template "/etc/logrotate.d/mongodb-#{new_resource.name}-logs" do
    source 'etc/logrotate.d/mongodb-logs.erb'
    cookbook 'MongoDB'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      cpath: "#{base}/log"
    )
  end
  new_resource.updated_by_last_action(t.updated_by_last_action?)

  if new_resource.default_instance
    link '/usr/bin/mongo' do
      to "#{base}/current/bin/mongo"
      link_type :symbolic
    end
  end
  
end
