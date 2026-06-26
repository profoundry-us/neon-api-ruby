# frozen_string_literal: true

require "rails/generators/base"

module NeonAuth
  module Generators
    # `rails g neon_auth:install` — writes the initializer and a migration that
    # adds a unique `neon_auth_id` (uuid) column to the users table.
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :table, type: :string, default: "users",
                           desc: "Table to add neon_auth_id to"

      # Rails calls this to timestamp the generated migration.
      def self.next_migration_number(_dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_initializer
        template "initializer.rb", "config/initializers/neon_auth.rb"
      end

      def create_migration
        migration_template "migration.rb", "db/migrate/add_neon_auth_id_to_#{table}.rb"
      end

      private

      def table
        options[:table]
      end
    end
  end
end
