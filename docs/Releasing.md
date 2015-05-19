# Releasing

## Performing releases

1. Edit and commit the version file in `lib/cloudformation-ruby-dsl/version.rb`. Bump the version based on the [version specification](#versioning-specification)
2. `git push` to origin/master
3. `rake release`

## Versioning specification

For this project, we will follow the methodology proposed by http://semver.org/spec/v2.0.0.html.

1. Major versions break existing interfaces.
2. Minor versions are additive only.
3. Patch versions are for backward-compatible bug fixes.