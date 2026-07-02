# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "set"
require_relative "object"

module NeonAPI
  # Development-time generator for lib/neon_api/types.rb.
  #
  # Reads the Neon OpenAPI specification and emits typed {NeonAPI::Object}
  # subclasses (NeonAPI::Types::*) for the success-response schema of every
  # operation the client covers, plus everything those schemas reference.
  # Regenerate after Neon updates their spec with:
  #
  #   rake types:generate              # fetches the published spec
  #   rake types:generate SPEC=v2.json # or use a local copy
  #
  # This file is a dev tool; the gem never loads it at runtime.
  class TypeGenerator
    DEFAULT_SPEC_URL = "https://neon.com/api_spec/release/v2.json"

    # The OpenAPI operations backing NeonAPI::Client / NeonAPI::Auth methods.
    #
    # nil    => the success response is a single named component schema, and the
    #           generated class keeps that name.
    # String => the success response is an inline allOf composite with no name of
    #           its own; the value names the merged class we synthesize.
    OPERATIONS = {
      # Account & API keys                                    Client#me
      "getCurrentUserInfo" => nil,
      "listApiKeys" => nil,                                 # Client#api_keys (array items)
      "createApiKey" => nil,                                # Client#api_key_create
      "revokeApiKey" => nil,                                # Client#api_key_revoke
      # Projects
      "listProjects" => "ProjectsList",                     # Client#projects
      "getProject" => nil,                                  # Client#project
      "createProject" => "ProjectCreated",                  # Client#project_create
      "updateProject" => "ProjectOperations",               # Client#project_update
      "deleteProject" => nil,                               # Client#project_delete
      # Branches
      "listProjectBranches" => "BranchesList",              # Client#branches
      "getProjectBranch" => "BranchDetail",                 # Client#branch
      "createProjectBranch" => "BranchCreated",             # Client#branch_create
      # Databases
      "listProjectBranchDatabases" => nil,                  # Client#databases
      "getProjectBranchDatabase" => nil,                    # Client#database
      "createProjectBranchDatabase" => nil,                 # Client#database_create
      "updateProjectBranchDatabase" => nil,                 # Client#database_update
      "deleteProjectBranchDatabase" => nil,                 # Client#database_delete
      # Endpoints
      "listProjectEndpoints" => nil,                        # Client#endpoints
      "getProjectEndpoint" => nil,                          # Client#endpoint
      "createProjectEndpoint" => nil,                       # Client#endpoint_create
      "updateProjectEndpoint" => nil,                       # Client#endpoint_update
      "deleteProjectEndpoint" => nil,                       # Client#endpoint_delete
      "startProjectEndpoint" => nil,                        # Client#endpoint_start
      "suspendProjectEndpoint" => nil,                      # Client#endpoint_suspend
      # Roles
      "listProjectBranchRoles" => nil,                      # Client#roles
      "getProjectBranchRole" => nil,                        # Client#role
      "createProjectBranchRole" => nil,                     # Client#role_create
      "deleteProjectBranchRole" => nil,                     # Client#role_delete
      "resetProjectBranchRolePassword" => nil,              # Client#role_reset_password
      "getProjectBranchRolePassword" => nil,                # Client#role_reveal_password
      # Operations, consumption & connection URIs
      "listProjectOperations" => "OperationsList",          # Client#operations
      "getProjectOperation" => nil,                         # Client#operation
      "getConsumptionHistoryPerProject" => "ConsumptionHistoryProjectsList",
      "getConnectionURI" => nil,                            # Client#connection_uri
      # Neon Auth (NeonAPI::Auth::Branch / OAuthProviders / Users)
      "createNeonAuth" => nil,                              # auth.enable
      "getNeonAuth" => nil,                                 # auth.config
      "updateNeonAuthConfig" => nil,                        # auth.update
      "listBranchNeonAuthOauthProviders" => nil,            # oauth_providers.list
      "addBranchNeonAuthOauthProvider" => nil,              # oauth_providers.add
      "updateBranchNeonAuthOauthProvider" => nil,           # oauth_providers.update
      "createBranchNeonAuthNewUser" => nil                  # users.create
    }.freeze

    # Ruby keywords we never use as reader names (dynamic access still works).
    RESERVED = %w[
      alias and begin break case class def defined? do else elsif end ensure
      false for if in module next nil not or redo rescue retry return self
      super then true undef unless until when while yield
    ].to_set.freeze

    # OpenAPI scalar type => YARD type.
    SCALAR_YARD = {
      "string" => "String", "integer" => "Integer", "number" => "Float",
      "boolean" => "Boolean", "object" => "NeonAPI::Object"
    }.freeze

    # The static top of the generated file (the header with provenance is
    # prepended per-run) and its closing lines.
    PRELUDE = <<~RUBY
      require_relative "object"

      module NeonAPI
        # Typed views over API responses. Every class here is a {NeonAPI::Object},
        # so hash-style access, `to_h`, the `?` suffix, and dynamic method access
        # keep working — including for fields newer than this generated file.
        module Types
          # Wrap a raw JSON value: hashes become `type` instances, arrays are
          # mapped element-wise, everything else (including nil) passes through.
          def self.wrap(value, type)
            case value
            when ::Hash then type.new(value)
            when ::Array then value.map { |item| wrap(item, type) }
            else value
            end
          end

    RUBY

    FOOTER = <<~RUBY
        end
      end
    RUBY

    # Load a spec from a local path or an http(s) URL (following redirects).
    def self.load_spec(source)
      body = source.start_with?("http://", "https://") ? fetch(source) : File.read(source)
      JSON.parse(body)
    end

    def self.fetch(url, limit = 3)
      raise "too many redirects fetching the spec" if limit.zero?

      response = Net::HTTP.get_response(URI(url))
      return fetch(response["location"], limit - 1) if response.is_a?(Net::HTTPRedirection)
      raise "GET #{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    # @param spec [Hash] the parsed OpenAPI document
    # @param operations [Hash] operationId => class-name-or-nil (see OPERATIONS)
    # @param source [String] recorded in the generated header for provenance
    def initialize(spec, operations: OPERATIONS, source: DEFAULT_SPEC_URL)
      @spec = spec
      @operations = operations
      @source = source
      @schemas = spec.dig("components", "schemas") || raise(ArgumentError, "spec has no component schemas")
      @classes = {} # class name => { properties:, required:, parts:, description: }
      @scalars = {} # schema name  => schema node ($ref'd enums/scalars, no class emitted)
    end

    # @return [String] the full source of lib/neon_api/types.rb
    def generate
      index = index_operations
      @operations.each do |operation_id, class_name|
        operation = index[operation_id] || raise(ArgumentError, "operationId #{operation_id} not in spec")
        register_response(operation_id, class_name, success_schema(operation))
      end
      render
    end

    private

    def index_operations
      index = {}
      @spec.fetch("paths").each_value do |methods|
        methods.each_value do |operation|
          index[operation["operationId"]] = operation if operation.is_a?(Hash) && operation["operationId"]
        end
      end
      index
    end

    def success_schema(operation)
      responses = operation.fetch("responses")
      code = %w[200 201].find { |c| responses.key?(c) } || responses.keys.find { |c| c.start_with?("2") }
      deref(responses.fetch(code)).dig("content", "application/json", "schema")
    end

    # Follow a {"$ref" => "#/components/..."} chain to the referenced node.
    def deref(node)
      ref = node.is_a?(Hash) ? node["$ref"] : nil
      return node unless ref

      deref(@spec.dig(*ref.delete_prefix("#/").split("/")) || raise(ArgumentError, "unresolvable #{ref}"))
    end

    def register_response(operation_id, class_name, schema)
      raise ArgumentError, "#{operation_id} has no JSON response schema" unless schema

      if schema["$ref"]
        register_schema(ref_name(schema["$ref"]))
      elsif schema["allOf"]
        raise ArgumentError, "#{operation_id}: composite response needs a class name" unless class_name

        register_composite(class_name, schema)
      elsif schema.dig("items", "$ref")
        register_schema(ref_name(schema.dig("items", "$ref")))
      else
        raise ArgumentError, "#{operation_id}: unsupported response shape #{schema.keys.inspect}"
      end
    end

    # Register a component schema: objects become classes (walking their refs),
    # everything else (enum strings, bare integers, ...) is noted as a scalar.
    def register_schema(name)
      return if @classes.key?(name) || @scalars.key?(name)

      schema = @schemas[name] || raise(ArgumentError, "unknown schema #{name}")
      shape = object_shape(schema)
      if shape
        @classes[name] = shape.merge(description: schema["description"])
        shape[:properties].each_value { |prop| register_property_refs(prop) }
      else
        @scalars[name] = schema
        register_property_refs(schema) # e.g. a named array-of-$ref schema
      end
    end

    # Synthesize a named class for an inline allOf response composite.
    def register_composite(name, schema)
      raise ArgumentError, "synthetic class #{name} collides with a component schema" if @schemas.key?(name)
      return if @classes.key?(name)

      parts = schema.fetch("allOf").map { |part| ref_name(part.fetch("$ref")) }
      shape = object_shape(schema) || raise(ArgumentError, "composite #{name} is not an object")
      @classes[name] = shape.merge(parts: parts)
      shape[:properties].each_value { |prop| register_property_refs(prop) }
    end

    # Resolve a schema (following $ref and merging allOf) into its object shape:
    # { properties:, required: } — or nil when it isn't an object.
    def object_shape(schema)
      return object_shape(deref(schema)) if schema["$ref"]
      return merged_shape(schema["allOf"]) if schema["allOf"]
      return nil unless schema["type"] == "object" || schema.key?("properties")

      { properties: schema["properties"] || {}, required: schema["required"] || [] }
    end

    def merged_shape(parts)
      properties = {}
      required = []
      parts.each do |part|
        shape = object_shape(part) || next
        properties.merge!(shape[:properties])
        required |= shape[:required]
      end
      { properties: properties, required: required }
    end

    def register_property_refs(prop)
      ref = property_ref(prop)
      register_schema(ref) if ref
    end

    # The single $ref a property points at — directly, via array items, or via a
    # one-element allOf wrapper — or nil for inline/scalar properties.
    def property_ref(prop)
      return ref_name(prop["$ref"]) if prop["$ref"]

      items = prop["items"]
      return ref_name(items["$ref"]) if items.is_a?(Hash) && items["$ref"]

      all_of = prop["allOf"]
      return ref_name(all_of.first["$ref"]) if all_of.is_a?(Array) && all_of.size == 1 && all_of.first["$ref"]

      nil
    end

    def ref_name(ref)
      ref.split("/").last
    end

    # ---- rendering -----------------------------------------------------------

    def render
      body = @classes.keys.sort.map { |name| class_source(name, @classes[name]) }.join("\n")
      +"" << header << PRELUDE << body << FOOTER
    end

    def header
      <<~HEADER
        # frozen_string_literal: true

        # =============================================================================
        # GENERATED FILE — DO NOT EDIT BY HAND. Regenerate with:  rake types:generate
        #
        # Typed response wrappers for the Neon API, generated from the OpenAPI
        # specification by lib/neon_api/type_generator.rb.
        #
        # Source:    #{@source}
        # Generated: #{Time.now.utc.strftime("%Y-%m-%d")} (#{@classes.size} classes)
        # =============================================================================

      HEADER
    end

    def class_source(name, meta)
      lines = ["# #{class_comment(name, meta)}", "class #{name} < NeonAPI::Object"]
      properties = meta[:properties].flat_map do |pname, pschema|
        property_source(pname.to_s, pschema, meta[:required]).map { |line| line.empty? ? line : "  #{line}" }
      end
      properties.shift while properties.first == "" # no leading blank inside the class
      lines.concat(properties) << "end" << ""
      lines.map { |line| line.empty? ? "\n" : "    #{line}\n" }.join
    end

    def class_comment(name, meta)
      if meta[:parts]
        "#{name} — merged (allOf) response: #{meta[:parts].join(" + ")}."
      else
        first_line(meta[:description]) || "Generated from the OpenAPI schema `#{name}`."
      end
    end

    def property_source(name, prop, required)
      lines = [""]
      desc = first_line(prop["description"]) || ref_description(prop)
      lines << "# #{desc}" if desc
      enum = enum_values(prop)
      lines << "# One of: #{enum.map(&:inspect).join(", ")}." if enum.any? && enum.size <= 8
      return lines << skip_comment(name) unless reader_name?(name)

      lines << "# @return [#{yard_type(prop, required.include?(name))}]"
      lines.concat(reader_body(name, prop))
    end

    def reader_body(name, prop)
      ref = property_ref(prop)
      body = ref && @classes.key?(ref) ? "Types.wrap(to_h[#{name.inspect}], #{ref})" : "self[#{name.inspect}]"
      ["def #{name}", "  #{body}", "end"]
    end

    def reader_name?(name)
      name.match?(/\A[a-z_][a-z0-9_]*\z/) && !RESERVED.include?(name) && !collisions.include?(name)
    end

    def skip_comment(name)
      reason = if collisions.include?(name)
                 "collides with a NeonAPI::Object method"
               else
                 "is not a valid method name"
               end
      "# NOTE: `#{name}` #{reason}; read it with obj[#{name.inspect}]."
    end

    def collisions
      @collisions ||= NeonAPI::Object.instance_methods.to_set(&:to_s)
    end

    def enum_values(prop)
      prop["enum"] || (property_ref(prop) && @scalars.dig(property_ref(prop), "enum")) || []
    end

    def ref_description(prop)
      ref = property_ref(prop)
      first_line(ref && (@scalars[ref] || @schemas[ref] || {})["description"])
    end

    def first_line(description)
      line = description.to_s.lines.first.to_s.strip
      return nil if line.empty?

      line.length > 94 ? "#{line[0, 91]}..." : line
    end

    def yard_type(prop, required)
      base = yard_base(prop)
      required ? base : "#{base}, nil"
    end

    def yard_base(schema)
      return ref_yard(ref_name(schema["$ref"])) if schema["$ref"]

      all_of = schema["allOf"]
      return ref_yard(ref_name(all_of.first["$ref"])) if all_of.is_a?(Array) && all_of.size == 1 &&
                                                         all_of.first["$ref"]

      scalar_yard(schema)
    end

    def scalar_yard(schema)
      return "Array<#{yard_base(schema["items"] || {})}>" if schema["type"] == "array"

      SCALAR_YARD.fetch(schema["type"], "Object")
    end

    def ref_yard(name)
      return name if @classes.key?(name)

      @scalars.key?(name) ? yard_base(@scalars[name]) : "Object"
    end
  end
end
