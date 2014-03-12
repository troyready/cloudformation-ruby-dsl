# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudformation-ruby-dsl/version'

Gem::Specification.new do |gem|
  gem.name          = "cloudformation-ruby-dsl"
  gem.version       = Cfn::Ruby::Dsl::VERSION
  gem.authors       = ["Shawn Smith", "Dave Barcelo", "Nathaniel Eliot", "Jona Fenocchi", "Tony Cui"]
  gem.email         = ["Shawn.Smith@bazaarvoice.com", "Dave.Barcelo@bazaarvoice.com", "Nathaniel.Eliot@bazaarvoice.com", "Jona.Fenocchi@bazaarvoice.com", "Tony.Cui@bazaarvoice.com"]
  gem.description   = %q{Ruby DSL library that provides a wrapper around the cfn-cmd.}
  gem.summary       = %q{Ruby DSL library that provides a wrapper around the cfn-cmd.  Written by [Bazaarvoice](http://www.bazaarvoice.com).}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = %w{lib bin}

  gem.add_runtime_dependency    'detabulator'
end
