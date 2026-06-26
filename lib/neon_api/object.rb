# frozen_string_literal: true

module NeonAPI
  # A thin, read-only wrapper around a parsed JSON response that allows both
  # hash-style (`obj["project"]`) and method-style (`obj.project`) access.
  #
  # Nested hashes and arrays are wrapped lazily, so `client.project(id).project.name`
  # reads naturally while `to_h` still returns plain Ruby data structures.
  #
  # @example
  #   obj = NeonAPI::Object.new("project" => { "id" => "abc", "name" => "Prod" })
  #   obj.project.name       #=> "Prod"
  #   obj["project"]["id"]   #=> "abc"
  #   obj.project.to_h       #=> { "id" => "abc", "name" => "Prod" }
  class Object
    # @param data [Hash] the parsed JSON object
    def initialize(data)
      raise ArgumentError, "NeonAPI::Object expects a Hash, got #{data.class}" unless data.is_a?(::Hash)

      @data = data
    end

    # Fetch a value by key. Accepts strings or symbols.
    # @return [Object, Array, scalar, nil]
    def [](key)
      wrap(@data[key.to_s])
    end

    # @return [Hash] the underlying plain-Ruby hash (with string keys)
    def to_h
      @data
    end
    alias to_hash to_h

    # @return [Array<String>] the keys present on this object
    def keys
      @data.keys
    end

    # @return [Boolean] whether the given key exists
    def key?(key)
      @data.key?(key.to_s)
    end
    alias has_key? key?
    alias include? key?

    def each(&block)
      @data.each(&block)
    end

    def ==(other)
      to_h == (other.is_a?(Object) ? other.to_h : other)
    end

    def inspect
      "#<NeonAPI::Object #{@data.inspect}>"
    end

    def respond_to_missing?(name, include_private = false)
      @data.key?(name.to_s) || super
    end

    # Method-style access to top-level keys. A trailing `?` returns truthiness.
    def method_missing(name, *args)
      key = name.to_s
      if key.end_with?("?") && @data.key?(key[0..-2])
        !!@data[key[0..-2]]
      elsif @data.key?(key)
        wrap(@data[key])
      else
        super
      end
    end

    private

    def wrap(value)
      case value
      when ::Hash  then Object.new(value)
      when ::Array then value.map { |item| wrap(item) }
      else value
      end
    end
  end
end
