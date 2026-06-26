##############################
# General commands
##############################

# Show available just commands
default:
    just --list

# Build the image but don't start the container
build:
    docker compose build

# Rebuild the image without using the cache
rebuild:
    docker compose build --no-cache

# Start the gem container in the background (builds if needed)
up:
    docker compose up -d --build

# Stop and remove the containers
down:
    docker compose down

# Show docker compose status
status:
    docker compose ps

# Follow container logs
logs:
    docker compose logs -f

# Prune Docker resources for this project (containers + named volumes)
clean:
    docker compose down --volumes --remove-orphans


##############################
# gem commands
##############################

# Re-run bundle install inside the running container (after changing deps)
bundle:
    docker compose exec -it gem bundle install

# Open a shell in the running container
shell:
    docker compose exec -it gem /bin/bash

# Open a Ruby/IRB console with the gem loaded
console:
    docker compose exec -it gem bin/console

# Run the full RSpec suite
test:
    docker compose exec -it gem bundle exec rspec

# Run RuboCop
lint:
    docker compose exec -it gem bundle exec rubocop

# Run RuboCop with auto-fix
lint-fix:
    docker compose exec -it gem bundle exec rubocop -A

# Run the default rake task (spec + rubocop), matching CI
check:
    docker compose exec -it gem bundle exec rake


##############################
# Build/Publish commands
##############################

# Build the gem into the pkg/ directory
gem-build:
    docker compose exec -it gem gem build neon-api.gemspec

# Push the built gem to RubyGems (requires credentials / MFA)
gem-publish version:
    docker compose exec -it gem gem push neon-api-{{version}}.gem
