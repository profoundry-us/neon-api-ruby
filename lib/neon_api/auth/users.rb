# frozen_string_literal: true

require_relative "../object"
require_relative "../types"

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
    #   users.create(email: "ada@example.com", name: "Ada")
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
      # @param name [String] the user's display name. The OpenAPI spec marks it
      #   optional, but the live API rejects requests without it (400,
      #   "[body.name] expected string, received null" — verified 2026-07).
      # @param password [String, nil] accepted by the live API but no longer in
      #   its documented request schema; the supported way to create a
      #   password-backed user is Better Auth sign-up ({BetterAuthClient#sign_up_email})
      # @param attributes [Hash] any additional fields Neon Auth accepts
      # @return [Types::NeonAuthCreateNewUserResponse]
      def create(email:, name:, password: nil, **attributes)
        body = { email: email, name: name, password: password, **attributes }.compact
        wrap(@connection.post(@path, body: body), Types::NeonAuthCreateNewUserResponse)
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

      def wrap(payload, type = Object)
        Types.wrap(payload, type)
      end
    end
  end
end
