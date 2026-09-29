# AGENTS.md - OntoPortal Web UI (AgroPortal fork)

Context for AI agents working in this repository.

## Project Overview

Ruby on Rails front end for OntoPortal ontology repositories, maintained by
AgroPortal. Nearly all data comes from the OntoPortal REST API; the local
database holds UI state only.

```
Browser ──> Rails UI (this repo) ──ontologies_api_client──> OntoPortal REST API
              │   └──> Memcached   sessions, Rails cache, API responses
              └──────> MySQL       Flipper flags, federated portals, licenses
```

- **Repository**: https://github.com/agroportal/ontoportal_web_ui (`origin`)
- **Upstream**: https://github.com/ontoportal/ontoportal_web_ui (`upstream`)
- **API client**: `ontologies_api_client` from
  `agroportal/ontologies_api_ruby_client`, branch `development`

## Tech Stack

- **Framework**: Rails 7.0.8
- **Ruby**: 3.1 (CI, Docker image, production). `mise.toml` still pins 2.7.8;
  ignore it.
- **Database**: MySQL 8.0 (`mysql2`)
- **Cache**: Memcached (`dalli`), also the session store
- **Templates**: Haml 5
- **View Components**: ViewComponent 2.83 + Lookbook 1.5 (`/lookbook`)
- **JavaScript**: esbuild (`jsbundling-rails`), Stimulus 3, Turbo (Drive
  disabled); legacy jQuery scripts through Sprockets
- **CSS**: SCSS (`sassc-rails`), Bootstrap 4.2
- **Feature flags**: Flipper, admin UI at `/admin/flipper`
- **Server**: Puma 5

## Development Setup (Docker)

To check changes during development, run the project in dev mode against
the stage API, with the API key from `.env`:

```bash
./bin/ontoportal dev --api-url https://data.stage.agroportal.eu/ \
  --api-key "$(grep '^API_KEY=' .env | cut -d= -f2)"
```

- Creates `.env`, `config/bioportal_config_development.rb` and
  `config/database.yml` from their samples when missing; writes the API URL
  and key into `.env`.
- Runs compose services `dev` (Rails, http://localhost:3000), `node`
  (`yarn build --watch`), `db` (MySQL 8.0) and `cache` (Memcached).
- Interactive: opens `nano` on the Rails credentials before booting; exit it
  to continue. Agents should ask a human to run it.
- `--api-client-path ../ontologies_api_ruby_client` mounts a local API client
  checkout.
- `--reset-cache` runs `docker compose down --volumes`: deletes the database,
  gem and asset volumes.
- `bin/ontoportal run "<cmd>"` runs a command in the `dev` container.
- Ruby, Haml, JS and SCSS changes reload; `config/bioportal_config_*.rb` and
  initializers need a restart.

## Testing

Minitest (`test/`) is the CI suite. RSpec (`spec/`) holds component, helper,
service and mailer specs; CI doesn't run it.

**Tests hit a live OntoPortal API** (`API_URL`, default
`http://localhost:9393`) with `WebMock.allow_net_connect!`. They create and
delete users, ontologies, categories, groups and agents as `admin`/`password`
(`test/helpers/application_test_helpers.rb`). Never point `API_URL` at a
shared or production portal while testing.

### Running

```bash
# Docker: boots a local API first unless --api-url is given
bin/ontoportal test                                          # all but system tests
bin/ontoportal test test/system/submission_flows_test.rb:75  # one test

# Host, as CI does
bin/run_api                        # local API on :9393, seeded with STY
RAILS_ENV=test bin/rails db:setup
RAILS_ENV=test bin/rails test -v
CI=true RAILS_ENV=test bin/rails assets:precompile
CI=true RAILS_ENV=test bin/rails test -v test/system/*
bundle exec rspec
```

### Notes

- `bin/run_api` clones `ontoportal-lirmm/ontoportal_docker` into
  `tmp/ontoportal_docker` and boots the API with `STARTER_ONTOLOGY`. Options
  come from `.env` (`OP_API_KEY`, `OP_API_URL`, `API_IMAGE_REPOSITORY`,
  `API_IMAGE_TAG`) or flags (`bin/run_api -h`). `bin/stop_api` stops it and
  deletes its volumes.
- Memcached must listen on `localhost:11211`; `config/environments/test.rb`
  hard-codes it.
- System tests use a remote Selenium at `http://localhost:4444` (compose
  `chrome-server`). `bin/rails test` skips `test/system/`. `CI=true` selects
  headless Chrome and eager loading.
- `test/fixtures/*.yml` are not ActiveRecord fixtures: `fixtures(:users)`
  returns OpenStructs (`test/test_helper.rb`).
- Every Flipper feature is enabled in tests (`FlipperSetup.test_configure!`).
- `spec/services/issue_creator_service_spec.rb` raises `NameError`:
  `GitHub::Client` is commented out in `config/initializers/graphql_client.rb`.

## Key Directories

```
app/
├── components/            # ViewComponents (Haml) + their Stimulus controllers
├── controllers/           # concerns/ holds shared controller logic
├── helpers/               # view helpers
├── javascript/
│   ├── controllers/            # page Stimulus controllers
│   ├── component_controllers/  # registers controllers from app/components/
│   └── mixins/                 # shared JS (useAjax, useTomSelect, ...)
├── assets/
│   ├── javascripts/       # legacy jQuery scripts (Sprockets)
│   ├── stylesheets/       # SCSS; themes/ and theme-variables.scss.erb
│   └── builds/            # esbuild output (generated)
├── lib/                   # flipper/ setup, kgcl/ change requests
├── models/                # ActiveRecord, local UI state only
├── services/
└── views/                 # Haml templates
config/
├── bioportal_config_*.rb  # portal settings ($globals); only _test.rb tracked
├── environments/          # development, test, staging, production, appliance
├── locales/               # en.yml, fr.yml (it and de are .sample)
└── deploy.rb              # Capistrano
bin/                       # ontoportal, run_api, stop_api, dev
lib/tasks/                 # flipper:rename, component_previews:generate
test/                      # Minitest; components/previews/ = Lookbook previews
spec/                      # RSpec
```

## Configuration

- `config/bioportal_config_<env>.rb` sets portal settings as globals, mostly
  from ENV. `config/environments/<env>.rb` requires it. Only the test one is
  tracked; create the others from `config/bioportal_config_env.rb.sample`.
- Key globals: `$REST_URL` (`API_URL`), `$API_KEY` (`API_KEY`), `$UI_URL`,
  `$SITE`, `$ORG`, `$UI_THEME`, `$RESOURCE_TERM`, `$READ_ONLY_PORTAL`,
  `$AGENTS_ENABLED`, `$SPARQL_ENDPOINT_URL`.
- New setting: add it to `bioportal_config_env.rb.sample`,
  `bioportal_config_test.rb` and, if env-driven, `.env.sample`. Deployed
  portals keep their own config file, so code must handle the global being
  `nil`.
- Production servers run `RAILS_ENV=appliance`.

## Conventions

- Read OntoPortal data through `ontologies_api_client`
  (`LinkedData::Client::Models::*`, `LinkedData::Client::HTTP`).
- Fetch user-supplied URLs only through `SsrfFilter`; see
  `app/helpers/check_resolvability_helper.rb`.
- New UI: a ViewComponent plus a Lookbook preview in
  `test/components/previews/`.
- Stimulus: register page controllers in `app/javascript/controllers/index.js`,
  component controllers in `app/javascript/component_controllers/index.js`.
- Turbo Drive is off (`app/javascript/application_esbuild.js`); use Turbo
  Frames and Streams.
- i18n: add each key to `en.yml` and `fr.yml`. Call `t(...)`:
  `InternationalisationHelper#t` swaps "ontology" for `$RESOURCE_TERM`.
- Flipper: features in `FlipperSetup::FEATURES` are enabled on first boot
  unless an admin already set them.
- Some gems are pinned for old production hosts (see `Gemfile` comments);
  don't bump them in passing.
- No RuboCop or ESLint config is committed. `bundle exec rubocop` runs with
  defaults; don't reformat code you don't change.
- Security: `bundle exec brakeman`. CI uploads its report to code scanning
  without failing the build.

## Git & CI

- Commits and PR titles follow Conventional Commits; see `CONTRIBUTING.md`.
- PRs target `master` of `agroportal/ontoportal_web_ui`. `gh` may resolve to
  `upstream`; pass `-R agroportal/ontoportal_web_ui`.
- Workflows: `tests.yml` (Minitest), `tests-system.yml` (system tests),
  `brakeman-analysis.yml`, `docker-image.yml` (pushes
  `agroportal/ontoportal_web_ui` to Docker Hub and GHCR from `master`,
  `development`, `stage`, `test` and releases).

## Deployment

- Capistrano (`config/deploy.rb`); stage files in `config/deploy/` are
  gitignored.
- `config/puma.rb`: in `production`, `staging` and `appliance`, Puma binds a
  unix socket for Nginx and redirects stdout to `log/puma.*.log`. Servers
  rely on both.

## Useful Links

- API client: https://github.com/agroportal/ontologies_api_ruby_client
- OntoPortal docs: https://ontoportal.github.io/documentation/
