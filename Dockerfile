# syntax=docker/dockerfile:1

# Development image for the neon-api gem.
#
# This mirrors the approach used by LocoMotion: we bundle the gem's
# dependencies into the image, then mount the working tree over the top at
# runtime (see docker-compose.yml) so edits on the host are reflected
# instantly inside the container.
#
# We default to Ruby 3.3 (the newest version exercised in CI). The gem
# supports >= 3.0; bump the matrix in .github/workflows/ci.yml and this tag
# together if that changes.
FROM ruby:3.3

# Basic toolchain. build-essential + git cover native extension gems (e.g.
# the optional rbnacl/libsodium path for EdDSA JWTs); tini gives us a proper
# init so the long-running container reaps signals cleanly.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libsodium-dev \
    tini \
    vim \
  && rm -rf /var/lib/apt/lists/*

ENV APP_HOME=/app
WORKDIR $APP_HOME

# Install dependencies first, before copying the full source, so this layer is
# cached and only re-runs when the gem's dependency surface changes. The
# gemspec is evaluated by `bundle install`, and it `require`s version.rb, so
# all three pieces must be present.
COPY neon-api.gemspec $APP_HOME/neon-api.gemspec
COPY Gemfile Gemfile* $APP_HOME/
COPY lib/neon_api/version.rb $APP_HOME/lib/neon_api/version.rb
RUN bundle install

# Convenience aliases for poking around inside the container.
RUN echo 'alias be="bundle exec"\nalias la="ls -al"' >> ~/.bashrc

# Keep the container running so we can `docker compose exec` into it. Real work
# (tests, console, lint) is run via `just` against this long-lived container.
ENTRYPOINT ["/usr/bin/tini", "--", "tail", "-f", "/dev/null"]
