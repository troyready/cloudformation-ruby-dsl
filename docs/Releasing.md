# Releasing

## Performing releases

0. Merge the desired commits to master. But merge them cleanly! See: [merging](#merging)
1. Edit and commit the version file in `lib/cloudformation-ruby-dsl-addedvars/version.rb`. Bump the version based on the [version specification](#versioning-specification)
2. `git push` to origin/master
3. `rake release`

## Versioning specification

For this project, we will follow the methodology proposed by http://semver.org/spec/v2.0.0.html.

1. Major versions break existing interfaces.
2. Minor versions are additive only.
3. Patch versions are for backward-compatible bug fixes.

## Merging

When you use the shiny green "Merge" button on a pull request, github creates a separate commit for the merge (because of the use of the `--no-ff` option). This is noisy and makes git history confusing. Instead of using the green merge button, merge the branch into master using [git-land](https://github.com/bazaarvoice/git-land#git-land) (or manually follow the steps described in the project).
