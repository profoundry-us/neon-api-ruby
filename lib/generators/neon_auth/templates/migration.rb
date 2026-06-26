# frozen_string_literal: true

class AddNeonAuthIdTo<%= table.camelize %> < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :<%= table %>, :neon_auth_id, :uuid
    add_index  :<%= table %>, :neon_auth_id, unique: true
  end
end
