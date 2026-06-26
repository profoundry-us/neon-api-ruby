# Docker-based development

You can do all of your work on this gem inside Docker, with nothing more than
Docker and [`just`](https://github.com/casey/just) installed on your host —
no system Ruby, no `rbenv`, no Bundler. This mirrors the setup used by
[LocoMotion](https://github.com/profoundry-us/loco-motion), pared down to what a
single, dependency-light gem needs.

## How it works

- **`Dockerfile`** builds a `ruby:3.3` image (the newest Ruby exercised in CI)
  and runs `bundle install` against the gemspec, Gemfile, and `version.rb`.
  Those three files are copied in *before* the rest of the source so the
  dependency layer stays cached and only rebuilds when the dependencies change.
- **`docker-compose.yml`** defines one service, `gem`. It mounts the working
  tree into the container at `/app`, so edits on the host are live inside the
  container. Dependencies are baked into the image at `/usr/local/bundle` (not
  under `/app`, so the mount doesn't shadow them); change the Gemfile/gemspec
  and `just rebuild` to reinstall. The container itself just stays alive
  (`tini` + `tail -f /dev/null`); real work happens via `docker compose exec`.
- **`justfile`** wraps the common `docker compose` invocations so you rarely
  type Docker commands directly.

## Quick start

```bash
# Build the image and start the container in the background
just up

# Run the test suite
just test

# Run RuboCop (and auto-fix)
just lint
just lint-fix

# Run spec + rubocop together (the default rake task, same as CI)
just check

# Open an IRB console with the gem loaded
just console

# Drop into a shell inside the container
just shell

# Stop the container when you're done
just down
```

Run `just` with no arguments to list every available command.

## Common tasks

| Goal                                   | Command                  |
| -------------------------------------- | ------------------------ |
| Build the image                        | `just build`             |
| Rebuild from scratch (no cache)        | `just rebuild`           |
| Start the container                    | `just up`                |
| Re-install gems after editing deps     | `just bundle`            |
| Run tests                              | `just test`              |
| Lint / auto-fix                        | `just lint` / `just lint-fix` |
| Console                                | `just console`           |
| Shell                                  | `just shell`             |
| Stop                                   | `just down`              |
| Remove containers + volumes            | `just clean`             |

## Notes

- After changing `Gemfile` or the gemspec, run `just rebuild` to reinstall
  dependencies into the image. (`just bundle` re-bundles inside the running
  container for a quick iteration, but that doesn't persist once the container
  is recreated — `just rebuild` is the durable path.)
- `Gemfile.lock` is committed, so the image and your host resolve to the same
  dependency versions. After a dependency change, run `just bundle` to refresh
  the lockfile in the working tree and commit it.
- The image installs `build-essential` and `libsodium-dev`, so native-extension
  gems compile and `rbnacl` (the EdDSA/Ed25519 path used to verify Neon Auth
  JWTs) works out of the box — including the EdDSA verification spec.

## Later: a demo / sandbox app

We intentionally do **not** ship a demo app yet. When we want one — for example,
a small Rails app that wires Neon Auth in via OmniAuth to exercise the gem
end-to-end — LocoMotion's multi-service layout is the model to copy:

1. Create the app under `docs/demo/` (or `examples/`) with its own
   `Dockerfile.demo`.
2. Add a `demo` service to `docker-compose.yml` that:
   - builds from that Dockerfile,
   - mounts the demo app **and** mounts this gem into the app's vendor path so
     the app uses the local working copy (LocoMotion mounts the repo at
     `vendor/loco_motion-rails`; the gem's Gemfile then points at it with
     `gem "neon-api", path: "vendor/neon-api"`),
   - publishes the app's port (e.g. `3000:3000`),
   - loads a gitignored `docs/demo/.env.local` for secrets (Neon API key, OAuth
     credentials) via `env_file`.
3. Add `demo`, `demo-shell`, `demo-console`, and `demo-test` recipes to the
   `justfile`, each running `docker compose exec -it demo ...`.

Keeping the demo app's configuration and secrets inside the demo service (never
in the gem container) is the key discipline — the gem container should never
need an `.env` file.
