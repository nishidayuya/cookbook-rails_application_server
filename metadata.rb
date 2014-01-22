name             "rails_application_server"
maintainer       "Yuya.Nishida."
maintainer_email "yuya@j96.org"
license          "X11 License"
description      "Installs/Configures rails_application_server"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version          "0.1.0"

recipe "rails_application_server", "Configures Rails application server"

depends "ruby_build"
depends "rbenv"
depends "passenger"
depends "passenger_apache2"
