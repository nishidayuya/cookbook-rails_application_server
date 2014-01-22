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

root = node["rails_application_server"]
base_path = Pathname(root["base_path"])
root["applications"].each do |name, c|
  home_path = base_path + name
  user_name = name

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
