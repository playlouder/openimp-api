module CI
  class Error < Exception
    def self.json_create properties
      raise new(properties["errormessage"])
    end
  end

  [:PermissionDenied, :NotImplemented, :Conflict, :BadParameters, :NotFound].each do |error|
    class_eval <<-CLASS
      class #{error} < Error
      end
    CLASS
  end


  # The +Asset+ class defines the core features of server-side objects, including the ability to autoinstantiate them
  # from _JSON_ for transport across the network.
  class Asset
    # Simple implementation of a +class inheritable accessor+.
    def self.class_inheritable_accessor(*args)
      args.each do |arg|
        class_eval "
          def self.#{arg}
            @#{arg} ||= superclass.#{arg} unless self == CI::Asset
          end 
          def self.#{arg}=(val)
            @#{arg}=val
          end
        "
      end
    end
    class_inheritable_accessor  :base_url, :api_class_name
    self.base_url = ""

    # Creates a canonical URL for the specified server-side object.
    def self.url id, *actions
      MediaFileServer.resolve self.base_url, id, actions.join("/")
    end

    # A +meta programming helper method+ which converts an API attribute into more manageable forms.
    def self.with_api_attribute api_attribute
      ruby_method = api_attribute.to_method_name
      api_key = api_attribute.to_sym
      yield ruby_method, api_key
    end

    # Defines an API attribute present on the current class and creates accessor methods for manupulating it.
    def self.api_attr_accessor *api_methods #:nodoc:
      Array.new(api_methods).each do |api_attribute|
        with_api_attribute(api_attribute) do |ruby_method, api_key|
          define_method(ruby_method) { @parameters[api_key] }
          define_method("#{ruby_method}=") do |value|
            @parameters[api_key] = value
          end
        end
      end
    end

    # Defines an API attribute as representing a collection of one or more server-side objects and creates
    # accessor methods for manipulating it.
    def self.has_many api_attribute
      with_api_attribute(api_attribute) do |ruby_method, api_key|
        define_method(ruby_method) { @parameters[api_attribute] || [] }
        define_method("#{ruby_method}=") do |hashes|
          @parameters[api_key] = hashes.map { |hash| Asset.create hash[:__CLASS__] }
        end
      end
    end

    # Defines an API attribute as being a reference to another object stored on the server, represented by a URL.
    def self.references api_attribute
      with_api_attribute(api_attribute) do |ruby_method, api_key|
        define_method(ruby_method) do
           @parameters[api_key].respond_to?(:__representation__) ? @parameters[api_key] : (@parameters[api_key] = Asset.load(@parameters[api_key]["__REPRESENTATION__"], :representation => true))
        end
      end
    end

    # Not all API classes use +Id+ as their primary key, therefore we allow the primary key to be explicitly
    # named whilst still keeping the notion of an id
    def self.api_primary_key api_attribute
      with_api_attribute(api_attribute) do |ruby_method, api_key|
        define_method(:primary_key) { api_key }
        define_method(:id) { @parameters[api_key] }
        define_method(:id=) do |value|
          @parameters[api_key] = value
        end
      end
      api_attr_accessor api_attribute
    end

    # We use a custom constructor to automatically load the correct object from the
    # CI MFS system if the parameters to +new+ include a +primary key+.
    def self.new parameters={}, *args
      asset = allocate
      case
      when parameters[asset.primary_key]
        asset = MediaFileServer.get(url(parameters[asset.primary_key]))
      when parameters['__REPRESENTATION__']
        asset = MediaFileServer.get(parameters['__REPRESENTATION__'])
      else
        asset.send :initialize, parameters, *args
      end
      asset
    end

    # Create an instance of this class from a JSON object.
    def self.json_create properties
      asset = allocate
      asset.send :initialize, properties
      asset
    end

    api_primary_key   :Id
    api_attr_accessor :__REPRESENTATION__

    def initialize parameters = {}
      @parameters = {}
      parameters.delete_if { |k, v| k == '__CLASS__' }.each { |k, v| self.send("#{k.to_method_name}=", v) rescue nil }
    end

    # Calculate a URL relative to the current server object.
    def url action = nil
      self.class.url id, action
    end

    def to_json *a
      self.parameters.inject({'__CLASS__' => self.class.name.sub(/CI::/i, 'API::')}) { |h, (k, v)|
        h[k] = case v
        when true then 1
        when false then 0
        else v.to_json(*a)
        end
      }.to_json(*a)
    end

    [:get, :get_octet_stream, :head, :delete].each do |m|
      class_eval <<-METHOD
        def #{m} action = nil
          MediaFileServer.#{m} url(action)
        end
      METHOD
    end

    def post properties, action = nil
      MediaFileServer.post url(action), properties
    end

    def put content_type, data
      MediaFileServer.put url(), content_type, data
    end

  protected
    def == asset
      parameters == asset.parameters
    end

    def replace_with! asset
      @parameters = asset.parameters
      self
    end

    def parameters
      @parameters.clone
    end
  end


  # An +Encoding+ describes the audio codec associated with a server-side audio file.
  class Encoding < Asset
    api_attr_accessor :Codec, :Family, :PreviewLength, :Channels, :Bitrate, :Description
    api_primary_key   :Name
    self.base_url = 'encoding'
    @@encodings = nil

    def self.synchronize
      @@encodings = MediaFileServer.get(url nil)
    end

    def self.encodings
      @@encodings.dup rescue nil
    end
=begin
    # We use a custom constructor to automatically load the correct object from the
    # CI MFS system if the parameters to +new+ include a +name+.
    def self.new parameters={}, *args
      super parameters.merge(:Id => parameters[:Name] || parameters[:name], :Name => nil, :name => nil), *args
    end
=end
  end


  # A +ContextualMethod+ is a method call avaiable on a server-side object.
  class ContextualMethod < Asset
    api_primary_key   :Name
  end
end