# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

# The default suite excludes spec/rails, which needs the isolated
# gemfiles/rails.gemfile bundle (Combustion). Run those with:
#   BUNDLE_GEMFILE=gemfiles/rails.gemfile bundle exec rspec spec/rails
RSpec::Core::RakeTask.new(:spec) do |t|
  t.exclude_pattern = "spec/rails/**/*_spec.rb"
end
RuboCop::RakeTask.new

task default: %i[spec rubocop]
