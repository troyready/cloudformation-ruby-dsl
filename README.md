# cloudformation-ruby-dsl

A Ruby DSL and helper utilities for building Cloudformation templates dynamically. Written by [Bazaarvoice](http://www.bazaarvoice.com).

## Motivation

Cloudformation templates often contain repeated stanzas, information which must be loaded from external sources, and other functionality that would be easier handled as code, instead of configuration. 

Consider when a userdata script needs to be added to a Cloudformation template. Traditionally, you would re-write the script by hand in a valid JSON format. Using the DSL, you can specify the file containing the script and generate the correct information at runtime.

    :UserData => base64(interpolate(file('userdata.sh')))

Additionally, Cloudformation templates are just massive JSON documents, making general readability and reusability an issue. The DSL allows not only a cleaner format (and comments!), but will also allow the same DSL template to be reused as needed.

## Installation

Run `gem install cloudformation-ruby-dsl` to install system-wide.

To use in a specific project, add `gem 'cloudformation-ruby-dsl'` to your Gemfile, and then run `bundle`.

## Usage

To convert existing JSON templates to use the DSL, run

    cfntemplate-to-ruby [EXISTING_CFN] > [NEW_NAME.rb]

You may need to preface this with `bundle exec` if you installed via Bundler.

Make the resulting file executable (`chmod +x [NEW_NAME.rb]`). It can respond to the following subcommands (which are listed if you run without parameters):
- `expand`: output the JSON template to the command line
- `diff`: compare output with existing JSON for a stack
- `cfn-validate-template`: run validation against the stack definition
- `cfn-create-stack`: create a new stack from the output
- `cfn-update-stack`: update an existing stack from the output

See [the example script](examples/cloudformation-ruby-script.rb) for more usage information of the DSL itself.
