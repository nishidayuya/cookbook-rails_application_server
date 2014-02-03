#
# Cookbook Name:: rails_application_server
# Recipe:: default
#
# Copyright 2014, Yuya.Nishida.
#
# X11 License
#

include_recipe "ruby_build"
include_recipe "rbenv::system"
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

  rbenv_gem "bundler" do
    rbenv_version c["ruby_version"]
    action :install
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

  template "database.yml" do
    path (application_config_path + "database.yml").to_s
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
      action :create
    end
  end

  web_app name do
    docroot (base_path + name).expand_path
    server_name "#{name}.#{node[:domain]}"
    ruby_bin_path = Pathname(node["rbenv"]["root_path"]) + "versions" +
      c["ruby_version"] + "bin" + "ruby"
    ruby ruby_bin_path
  end
end

group "rails-applications" do
  members root["applications"].keys
  action :create
end
