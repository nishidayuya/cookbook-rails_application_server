#
# Cookbook Name:: rails_application_server
# Recipe:: default
#
# Copyright 2014, Yuya.Nishida.
#
# X11 License
#

include_recipe "passenger_apache2"
include_recipe "postgresql::server"
include_recipe "database"
include_recipe "database::postgresql"

root = node["rails_application_server"]
base_path = Pathname(root["base_path"])
root["applications"].each do |name, c|
  home_path = base_path + name
  user_name = name
  database_user_name = name
  database_server_connection_configuration = {
    host: "localhost",
    username: "postgres",
    password: node["postgresql"]["password"]["postgres"],
  }

  user user_name do
    comment "an user for #{name}"
    home home_path.to_s
    password nil
    supports manage_home: true
  end

  ssh_path = home_path + ".ssh"
  directory ssh_path.to_s do
    owner user_name
    mode 0700
  end

  file (ssh_path + "authorized_keys").to_s do
    owner user_name
    mode 0600
    content c["deploy_keys"].map { |line|
      line + "\n"
    }.join
  end

  application_shared_path = home_path + "shared"
  directory application_shared_path.to_s do
    owner user_name
    mode 0755
  end

  application_config_path = application_shared_path + "config"
  directory application_config_path.to_s do
    owner user_name
    mode 0755
  end

  database_yml_path = application_config_path + "database.yml"
  template "database.yml" do
    path database_yml_path.to_s
    owner user_name
    mode 0600
    source "database.yml.erb"
    variables({
                name: name,
                database_user: database_user_name,
                database_password: c["database_password"],
              })
  end

  %w(production test).each do |environment|
    d = "#{name}_#{environment}"

    database_user database_user_name do
      provider Chef::Provider::Database::PostgresqlUser
      connection database_server_connection_configuration
      password c["database_password"]
      database_name d
      privileges [:all]
      action :create
    end

    database d do
      provider Chef::Provider::Database::Postgresql
      connection database_server_connection_configuration
      owner database_user_name
      encoding "UTF8"
      action :create
    end
  end

  current_path = home_path + "current"
  web_app name do
    docroot (current_path + "public").expand_path
    server_name c["server_name"] || "#{name}.#{node[:domain]}"
    ruby c["ruby_bin_path"]
  end

  backups_path = home_path + "backups"
  directory backups_path.to_s do
    owner user_name
    mode 0755
  end

  template "backup-db" do
    path "/etc/cron.daily/backup-db-#{name}_production"
    mode 0755
    source "backup-db.erb"
    variables({
                ruby: c["ruby_bin_path"],
                backups_path: backups_path,
                database_yml_path: database_yml_path,
                user_name: user_name,
              })
  end

  template "logrotate.d" do
    path "/etc/logrotate.d/#{name}"
    mode 0644
    source "logrotate.conf.erb"
    variables({
                current_path: current_path,
              })
  end
end

group "rails-applications" do
  members root["applications"].keys
  action :create
end
