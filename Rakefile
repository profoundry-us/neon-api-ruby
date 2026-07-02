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

namespace :types do
  desc "Regenerate lib/neon_api/types.rb from the Neon OpenAPI spec (SPEC=path-or-url to override)"
  task :generate do
    require_relative "lib/neon_api/type_generator"

    source = ENV.fetch("SPEC", NeonAPI::TypeGenerator::DEFAULT_SPEC_URL)
    spec = NeonAPI::TypeGenerator.load_spec(source)
    code = NeonAPI::TypeGenerator.new(spec, source: source).generate
    File.write("lib/neon_api/types.rb", code)
    puts "Wrote lib/neon_api/types.rb (#{code.lines.count} lines) from #{source}"
  end
end

namespace :matrix do
  desc "Regenerate the per-Ruby CI lockfiles (gemfiles/ruby_<ver>.gemfile.lock) via Docker"
  task :lock do
    # The CI Ruby versions, each with a committed lockfile resolved under that
    # Ruby (so a single modern lock can't pin transitive deps that dropped older
    # Rubies). Keep in sync with the matrix in .github/workflows/ci.yml.
    rubies = %w[3.0 3.1 3.2 3.3]

    rubies.each do |version|
      gemfile = "gemfiles/ruby_#{version}.gemfile"
      File.write(gemfile, <<~RUBY)
        # frozen_string_literal: true

        # Per-Ruby bundle for the CI matrix (Ruby #{version}). Reuses the root Gemfile so the
        # dev/test deps are identical to local; only the resolved lockfile differs, so
        # each Ruby gets versions it can actually install. Regenerate with:
        #   rake matrix:lock        (resolves every version under its real Ruby via Docker)
        eval_gemfile File.expand_path("../Gemfile", __dir__)
      RUBY

      puts "Locking #{gemfile} under ruby:#{version}..."
      sh "docker run --rm -v #{Dir.pwd}:/work -w /work ruby:#{version} bash -c " \
         "'BUNDLE_GEMFILE=#{gemfile} bundle lock && " \
         "BUNDLE_GEMFILE=#{gemfile} bundle lock --add-platform x86_64-linux'"
    end
  end
end
