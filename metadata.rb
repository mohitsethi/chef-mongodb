name             'mongodb'
version          '1.0.3'
maintainer       'Mohit Sethi'
maintainer_email 'mohit@sethis.in'
license          'Apache'
description      'Installs/Configures mongodb, multi instance support'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))

version          '1.0.6'

source_url       'https://github.com/mohitsethi/chef-mongodb'
issues_url       'https://github.com/mohitsethi/chef-mongodb/issues'

%w(ubuntu debian).each do |os|
  supports os
end

depends 'runit'