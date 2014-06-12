# cloudformation-ruby-dsl

A Ruby DSL and helper utilities for building Cloudformation templates dynamically.

Written by [Bazaarvoice](http://www.bazaarvoice.com): see [the contributors page](https://github.com/bazaarvoice/cloudformation-ruby-dsl/graphs/contributors) and [the initial contributions](https://github.com/bazaarvoice/cloudformation-ruby-dsl/blob/master/initial_contributions.md) for more details.

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
- `expand`: output the JSON template to the command line (takes optional `--nopretty` to minimize the output)
- `diff`: compare output with existing JSON for a stack
- `cfn-validate-template`: run validation against the stack definition
- `cfn-create-stack`: create a new stack from the output
- `cfn-update-stack`: update an existing stack from the output

Below are the various functions currently available in the DSL. See [the example script](examples/cloudformation-ruby-script.rb) for more usage information.

### DSL Statements

Add the named object to the appropriate collection.
- `parameter(name, options)` (may be marked :Immutable, which will raise error on a later change)
- `mapping(name, options)`
- `condition(name, options)`
- `resource(name, options)`
- `output(name, options)`

### Cloudformation Function Calls

Invoke a native Cloudformation function.
- `base64(value)`
- `find_in_map(map, key, name)`
- `get_att(resource, attribute)`
- `get_azs(region)`
- `join(delim, *list)`
- `select(index, list)`
- `ref(name)`
- `no_value()`

### Utility Functions

Additional capabilities for file inclusion, etc.
- `tag(tag)`: add tags to the stack, which are inherited by all resources in that stack; can only be used at launch
- `file(name)`: return the named file as a string, for further use
- `load_from_file(filename)`: load the named file by a given type; currently handles YAML, JSON, and Ruby
- `interpolate(string)`: embed CFN references into a string (`{{ref('Service')}}`) for later interpretation by the CFN engine
- `Table.load(filename)`: load a table from the listed file, which can then be turned into mappings (via `get_map`)
