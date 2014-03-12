unless RUBY_VERSION >= '1.9'
  # This script uses Ruby 1.9 functions such as Enumerable.slice_before and Enumerable.chunk
  $stderr.puts "This script requires ruby 1.9+.  On OS/X use Homebrew to install ruby 1.9:"
  $stderr.puts "  brew install ruby"
  exit(2)
end

require 'rubygems'
require 'csv'
require 'json'
require 'yaml'
require 'erb'

############################# Command-line and "cfn-cmd" Support

# Parse command-line arguments based on cfn-cmd syntax (cfn-create-stack etc.) and return the parameters and region
def cfn_parse_args()
  parameters = {}
  region = 'us-east-1'
  stack_name = ARGV[1] && !(/^-/ =~ ARGV[1]) ? ARGV[1] : '<stack-name>'
  ARGV.slice_before(/^--/).each do |name, value|
    if name == '--parameters' && value
      parameters = Hash[value.split(/;/).map { |s| s.split(/=/, 2) }]
    elsif name == '--region' && value
      region = value
    end
  end
  [parameters, region, stack_name]
end

def cfn_cmd(template)
  unless %w(expand diff cfn-validate-template cfn-create-stack cfn-update-stack).include?(ARGV[0])
    $stderr.puts "usage: #{$PROGRAM_NAME} <expand|diff|cfn-validate-template|cfn-create-stack|cfn-update-stack>"
    exit(2)
  end
  unless (ARGV & %w(--template-file --template-url)).empty?
    $stderr.puts "#{File.basename($PROGRAM_NAME)}:  The --template-file and --template-url command-line options are not allowed."
    exit(2)
  end

  # Find parameters where extension attribute :Immutable is true then remove it from the
  # cfn template since we can't pass it to CloudFormation.
  immutable_parameters = template.excise_parameter_attribute!(:Immutable)

  # Tag CloudFormation stacks based on :Tags defined in the template
  cfn_tags = template.excise_tags!.sort
  # The command line string looks like:
  #   --tag "Key=key; Value=value" --tag "Key2=key2; Value2=value"
  cfn_tags_options = cfn_tags.map { |k| "--tag \"Key=#{k.split('=')[0]}; Value=#{k.split('=')[1]}\" " }.join('').rstrip.split(' ')

  template_string = JSON.pretty_generate(template)

  # example: <template.rb> cfn-create-stack my-stack-name --parameters "Env=prod" --region eu-west-1
  # Execute the AWS CLI cfn-cmd command to validate/create/update a CloudFormation stack.
  temp_file = write_temp_file($PROGRAM_NAME, 'expanded.json', template_string)

  cmdline = ['cfn-cmd'] + ARGV + ['--template-file', temp_file] + cfn_tags_options

  if ARGV[0] == 'expand'
    # Write the pretty-printed JSON template to stdout.
    # example: <template.rb> expand --parameters "Env=prod" --region eu-west-1
    puts template_string
    
    exit(true)

  elsif ARGV[0] == 'diff'
    # example: <template.rb> diff my-stack-name --parameters "Env=prod" --region eu-west-1
    # Diff the current template for an existing stack with the expansion of this template.

    # The --parameters and --tag options were used to expand the template but we don't need them anymore.  Discard.
    _, cfn_options = extract_options(ARGV[1..-1], %w(), %w(--parameters --tag))

    # Separate the remaining command-line options into options for 'cfn-cmd' and options for 'diff'.
    cfn_options, diff_options = extract_options(cfn_options, %w(),
      %w(--stack-name --region --parameters --connection-timeout -I --access-key-id -S --secret-key -K --ec2-private-key-file-path -U --url))

    # If the first argument is a stack name then shift it from diff_options over to cfn_options.
    if diff_options[0] && !(/^-/ =~ diff_options[0])
      cfn_options.unshift(diff_options.shift)
    end

    # Run CloudFormation commands to describe the existing stack
    cfn_options_string           = cfn_options.map { |arg| "'#{arg}'" }.join(' ')
    old_template_string          = exec_capture_stdout("cfn-cmd cfn-get-template #{cfn_options_string}")
    old_stack_description        = exec_capture_stdout("cfn-cmd cfn-describe-stacks #{cfn_options_string} --show-long")
    old_stack_description_parsed = CSV.parse_line(old_stack_description)
    old_stack_cfn_tags           = old_stack_description_parsed[13].split(';').sort
    old_parameters_string        = old_stack_description_parsed[6]

    # Sort the parameters strings alphabetically to make them easily comparable
    old_parameters_string = (old_parameters_string || '').split(';').sort.map { |s| %Q(PARAMETER "#{s}"\n) }.join
    parameters_string     = template.parameters.map { |k, v| k + '=' + v.to_s }.sort.map { |s| %Q(PARAMETER "#{s}"\n) }.join

    # Diff the expanded template with the template from CloudFormation.
    old_temp_file = write_temp_file($PROGRAM_NAME, 'current.json', old_parameters_string + old_template_string)
    new_temp_file = write_temp_file($PROGRAM_NAME, 'expanded.json', parameters_string + %Q(TEMPLATE  "#{template_string}\n"\n))

    # Compare CloudFormation tags
    unless cfn_tags == old_stack_cfn_tags
      puts "Tag differences:\n"
      puts (old_stack_cfn_tags - cfn_tags).map {|tag| "< #{tag}" }
      puts "---"
      puts (cfn_tags - old_stack_cfn_tags).map {|tag| "> #{tag}" }
      puts "\n"
    end

    # Compare templates
    system(*["diff"] + diff_options + [old_temp_file, new_temp_file])

    File.delete(old_temp_file)
    File.delete(new_temp_file)

    exit(true)

  elsif ARGV[0] == 'cfn-validate-template'
    # The cfn-validate-template command doesn't support --parameters so remove it if it was provided for template expansion.
    _, cmdline = extract_options(cmdline, %w(), %w(--parameters --tag))

  elsif ARGV[0] == 'cfn-update-stack'
    # If updating a stack and some parameters are marked as immutable, fail if the new parameters don't match the old ones.
    if not immutable_parameters.empty?

      # Pick out the subset of cfn-update-stack options that apply to cfn-describe-stacks.
      cfn_options, other_options = extract_options(ARGV[1..-1], %w(),
        %w(--stack-name --region --connection-timeout -I --access-key-id -S --secret-key -K --ec2-private-key-file-path -U --url))

      # If the first argument is a stack name then shift it over to cfn_options.
      if other_options[0] && !(/^-/ =~ other_options[0])
        cfn_options.unshift(other_options.shift)
      end

      # Run CloudFormation command to describe the existing stack
      cfn_options_string = cfn_options.map { |arg| "'#{arg}'" }.join(' ')
      old_stack_description = exec_capture_stdout("cfn-cmd cfn-describe-stacks #{cfn_options_string} --show-long")
      old_parameters_string = CSV.parse_line(old_stack_description)[6]

      old_parameters = Hash[(old_parameters_string || '').split(';').map { |s| s.split('=', 2) }]
      new_parameters = template.parameters

      immutable_parameters.sort.each do |param|
        if old_parameters[param].to_s != new_parameters[param].to_s
          $stderr.puts "Error: cfn-update-stack may not update immutable parameter " +
                           "'#{param}=#{old_parameters[param]}' to '#{param}=#{new_parameters[param]}'."
          exit(false)
        end
      end
    end

    # The cfn-update-stack command doesn't support --tag options, so remove it and validate against the existing stack to ensure they aren't different
    _, cmdline = extract_options(cmdline, %w(), %w(--tag))
    # 13 is the tag column; it's also the last column (size-1)
    old_cfn_tags = CSV.parse_line(exec_capture_stdout("cfn-cmd cfn-describe-stacks #{cfn_options_string} --show-long"))[13].split(';').sort

    # compare the sorted arrays for an exact match
    if cfn_tags != old_cfn_tags
      $stderr.puts "CloudFormation stack tags do not match and cannot be updated. You must either use the same tags or create a new stack." +
                      "\n" + (old_cfn_tags - cfn_tags).map {|tag| "< #{tag}" }.join("\n") +
                      "\n" + "---" +
                      "\n" + (cfn_tags - old_cfn_tags).map {|tag| "> #{tag}"}.join("\n")
      exit(false)
    end
  end

  # Execute command cmdline
  unless system(*cmdline)
    $stderr.puts "\nExecution of 'cfn-cmd' failed.  To facilitate debugging, the generated JSON template " +
                     "file was not deleted.  You may delete the file manually if it isn't needed: #{temp_file}"
    exit(false)
  end

  File.delete(temp_file)

  exit(true)
end

def exec_capture_stdout command
  stdout = `#{command}`
  unless $?.success?
    $stderr.puts stdout unless stdout.empty?  # cfn-cmd sometimes writes error messages to stdout
    exit(false)
  end
  stdout
end

def write_temp_file(name, suffix, content)
  path = File.absolute_path("#{name}.#{suffix}")
  File.open(path, 'w') { |f| f.write content }
  path
end

def extract_options(args, opts_no_val, opts_1_val)
  args = args.clone
  opts = []
  rest = []
  while (arg = args.shift) != nil
    if opts_no_val.include?(arg)
      opts.push(arg)
    elsif opts_1_val.include?(arg)
      opts.push(arg)
      opts.push(arg) if (arg = args.shift) != nil
    else
      rest.push(arg)
    end
  end
  [opts, rest]
end

############################# Generic DSL

class JsonObjectDSL
  def initialize(&block)
    @dict = {}
    instance_eval &block
  end

  def value(values)
    @dict.update(values)
  end

  def default(key, value)
    @dict[key] ||= value
  end

  def compact!()
    remove_nil(@dict)
  end

  def to_json(*args)
    compact!
    @dict.to_json(*args)
  end

  def print()
    puts JSON.pretty_generate(self)
  end
end

# In general, eliminate nil values.  If you really need it, create a wrapper class like "class JsonNullDSL; def to_json(*args) nil.to_json(*args) end end"
def remove_nil(val)
  case val
    when Array
      val.compact!
      val.each { |v| remove_nil(v) }
    when Hash
      val.delete_if { |k, v| k == nil || v == nil }
      val.values.each { |v| remove_nil(v) }
    when JsonObjectDSL
      val.compact!
    else
  end
end

############################# CloudFormation DSL

# main entry point
def template(&block)
  TemplateDSL.new(&block)
end

class TemplateDSL < JsonObjectDSL
  attr_reader :parameters, :aws_region, :aws_stack_name

  def initialize()
    @parameters, @aws_region, @aws_stack_name = cfn_parse_args
    super
  end

  def exec!()
    cfn_cmd(self)
  end

  def parameter(name, options)
    default(:Parameters, {})[name] = options
    @parameters[name] ||= options[:Default]
  end

  # Find parameters where the specified attribute is true then remove the attribute from the cfn template.
  def excise_parameter_attribute!(attribute)
    marked_parameters = []
    @dict.fetch(:Parameters, {}).each do |param, options|
      if options.delete(attribute.to_sym) or options.delete(attribute.to_s)
        marked_parameters << param
      end
    end
    marked_parameters
  end

  def mapping(name, options)
    # if options is a string and a valid file then the script will process the external file.
    if options.is_a?(String)
      raise("File #{options} is not accessible. Error!") unless File.exists?(options)
      filename = options

      # Figure out what the file extension is and process accordingly.
      case File.extname(filename)
        when ".rb"
          options = eval(File.open(filename).read)['Mappings']
        when ".json"
          options = JSON.load(File.open(filename))['Mappings']
        when ".yaml"
          options = YAML::load_file(filename)['Mappings']
        else
          raise("Do not recognize extension of #{filename}.")
      end
      default(:Mappings, {})[name] = options

    elsif options.is_a?(Hash)
      default(:Mappings, {})[name] = options
    else
      raise("Options for mapping #{name} is neither a string or a hash.  Error!")
    end
  end

  def excise_tags!
    tags = []
    @dict.fetch(:Tags, {}).each do | tag_name, tag_value |
      tags << "#{tag_name}=#{tag_value}"
    end
    @dict.delete(:Tags)
    tags
  end

  def tag(tag)
    tag.each do | name, value |
      default(:Tags, {})[name] = value
    end
  end

  def resource(name, options) default(:Resources, {})[name] = options end

  def output(name, options) default(:Outputs, {})[name] = options end

  def find_in_map(map, key1, key2)
    # Eagerly evaluate mappings when all keys are known at template expansion time
    if map.is_a?(String) && key1.is_a?(String) && key2.is_a?(String)
      # We don't know whether the map was built with string keys or symbol keys.  Try both.
      def get(map, key) map[key] || map.fetch(key.to_sym) end
      get(get(@dict.fetch(:Mappings).fetch(map), key1), key2)
    else
      { :'Fn::FindInMap' => [ map, key1, key2 ] }
    end
  end
end

def base64(value) { :'Fn::Base64' => value } end

def find_in_map(map, key1, key2) { :'Fn::FindInMap' => [ map, key1, key2 ] } end

def get_att(resource, attribute) { :'Fn::GetAtt' => [ resource, attribute ] } end

def get_azs(region = '') { :'Fn::GetAZs' => region } end

def join(delim, *list)
  case list.length
    when 0 then ''
    when 1 then list[0]
    else {:'Fn::Join' => [ delim, list ] }
  end
end

# Variant of join that matches the native CFN syntax.
def join_list(delim, list) { :'Fn::Join' => [ delim, list ] } end

def select(index, list) { :'Fn::Select' => [ index, list ] } end

def ref(name) { :Ref => name } end

# Read the specified file and return its value as a string literal
def file(filename) File.read(File.absolute_path(filename, File.dirname($PROGRAM_NAME))) end

# Interpolates a string like "NAME={{join('-', ref('Env'), ref('Service'))}}" and returns a
# CloudFormation "Fn::Join" operation using the specified delimiter.  Anything between {{
# and }} is interpreted as a Ruby expression and eval'd.  This is especially useful with
# Ruby "here" documents.
def join_interpolate(delim, string, overrides={}.freeze)
  list = []
  while string.length > 0
    head, match, tail = string.partition(/\{\{.*?\}\}/)
    list << head if head.length > 0
    if match.length > 0
      match_expr = match[2..-3]
      if overrides[match_expr]
        list << overrides[match_expr]
      else
        list << eval(match_expr)
      end
    end
    string = tail
  end

  # If 'delim' is specified, return a two-level set of joins: a top-level join() with the
  # specified delimiter and nested join()s on the empty string as necessary.
  if delim != ''
    # If delim=="\n", split "abc\ndef\nghi" into ["abc", "\n", "def", "\n", "ghi"] so the newline
    # characters are by themselves.  Then join() the values in each chunk between newlines.
    list = list.flat_map do |v|
      if v.is_a?(String)
        v.split(Regexp.new("(#{Regexp.escape(delim)})")).reject { |s| s == '' }
      else
        [ v ]
      end
    end.chunk { |v| v == delim }.map do |k, a|
      join('', *a) unless k
    end.compact
  end

  join(delim, *list)
end

# This class is used by erb templates so they can access the parameters passed
class Namespace
  attr_accessor :params
  def initialize(hash)
    @params = hash
  end
  def get_binding
    binding
  end
end

# Combines the provided ERB template with optional parameters
def erb_template(filename, params = {})
  renderer = ERB.new(file(filename), nil, '-')
  ERB.new(file(filename), nil, '-').result(Namespace.new(params).get_binding)
end