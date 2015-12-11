require 'chef/resource/lwrp_base'

class Chef
  class Resource
    class MongoDBInstance < Chef::Resource::LWRPBase
      provides :mongodb_instance

      self.resource_name = :mongodb_instance
      actions :create, :delete
      default_action :create

      attribute :client_name, kind_of: String, name_attribute: true, required: true
      attribute :package_name, kind_of: Array, default: nil
      attribute :package_version, kind_of: String, default: nil
      attribute :version, kind_of: String, default: nil # mongodb_version
    end
  end
end