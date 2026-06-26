# frozen_string_literal: true

require_relative "../object"

module NeonAPI
  module Auth
    # Manage Neon Auth users for a branch's integration.
    #
    # Neon Auth keeps user state in your database (the `neon_auth.user` table on
    # the `better_auth` backend), so for read-heavy work you can also query that
    # table directly from Rails. This API is for administrative actions: creating users,
    # changing roles, and deleting users.
    #
    # Accessed via `client.auth(project_id, branch_id).users`.
    #
    # @example
    #   users = client.auth(project_id, branch_id).users
    #   users.create(email: "ada@example.com", password: "s3cret")
    #   users.set_role(user_id, role: "admin")
    #   users.delete(user_id)
    class Users
      # @param connection [NeonAPI::Connection]
      # @param base_path [String] the branch auth base path
      def initialize(connection:, base_path:)
        @connection = connection
        @path = "#{base_path}/users"
      end

      # Create a user.
      #
      # @param email [String]
      # @param password [String, nil] optional; omit for passwordless/OAuth-only
      # @param attributes [Hash] any additional fields Neon Auth accepts
      #   (e.g. :display_name, :role)
      # @return [NeonAPI::Object]
      def create(email:, password: nil, **attributes)
        body = { email: email, password: password, **attributes }.compact
        wrap(@connection.post(@path, body: body))
      end

      # Update a user (the underlying endpoint is PUT).
      #
      # @param user_id [String]
      # @param attributes [Hash] fields to set (e.g. :role, :display_name)
      # @return [NeonAPI::Object]
      def update(user_id, **attributes)
        wrap(@connection.put("#{@path}/#{user_id}", body: attributes))
      end

      # Convenience for the common case of changing a user's role.
      # @param user_id [String]
      # @param role [String]
      # @return [NeonAPI::Object]
      def set_role(user_id, role:)
        update(user_id, role: role)
      end

      # Delete a user.
      # @param user_id [String]
      # @return [NeonAPI::Object]
      def delete(user_id)
        wrap(@connection.delete("#{@path}/#{user_id}"))
      end
      alias remove delete

      private

      def wrap(payload)
        payload.is_a?(::Hash) ? Object.new(payload) : payload
      end
    end
  end
end
