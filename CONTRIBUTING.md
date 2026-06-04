# Contributing to OmmicomMail

Thank you for helping improve OmmicomMail.

OmmicomMail is developed based on the original Postal project. Contributions should keep the project stable, practical, and easy to operate as a self-hosted mail server.

## Before You Start

Please check existing issues or discussions before starting a large change. For small fixes, documentation updates, and focused improvements, feel free to open a pull request directly.

Good contributions usually include:

* A clear explanation of the problem being solved
* A focused change set
* Tests or manual verification notes when behavior changes
* No unrelated formatting or refactoring

## Development Requirements

You will need:

* Ruby 3.2.2
* Bundler
* MySQL or MariaDB
* OpenSSL for generating signing keys

The database user must be able to create databases because OmmicomMail creates message databases for mail servers.

## Clone the Repository

```bash
git clone git@github.com:scoppy9201/OmmicomMail.git
cd OmmicomMail
```

Install dependencies:

```bash
bundle install
```

## Configuration

Configuration is handled through YAML files or environment variables.

For development, copy the example configuration:

```bash
mkdir -p config/postal
cp config/examples/development.yml config/postal/postal.yml
```

Generate a signing key:

```bash
openssl genrsa -out config/postal/signing.key 2048
```

For tests, use the test example:

```bash
cp config/examples/test.yml config/postal/postal.test.yml
```

Environment variables can also be placed in `.env` or `.env.test`.

## Running Locally

Use the project binaries from the repository root:

```bash
bin/dev
```

Useful commands:

* `bin/dev` runs the application components for development
* `bin/postal` runs the OmmicomMail/Postal command line tools
* `bin/rails` runs Rails commands
* `bin/rspec` runs the test suite

## Database Initialization

After configuration is ready, initialize the database and create your first user:

```bash
bin/postal initialize
bin/postal make-user
```

## Testing

Run the test suite before opening a pull request when possible:

```bash
bin/rspec
```

If you cannot run tests locally, mention that in the pull request and include the manual checks you performed.

## Pull Request Guidelines

Please keep pull requests focused. A good pull request should:

* Describe what changed and why
* Reference related issues when available
* Include screenshots for UI changes
* Include tests for application behavior changes
* Avoid committing local secrets, generated logs, database dumps, or machine-specific files

## Commit Style

Use short, direct commit messages:

```text
Fix SMTP endpoint validation
Update README branding
Add webhook delivery test
```

## Security

Do not open a public issue for sensitive security problems. Please report security concerns privately according to the instructions in `SECURITY.md`.

## Attribution

OmmicomMail is based on the original Postal project. Please preserve upstream license notices and attribution when modifying files derived from Postal.
