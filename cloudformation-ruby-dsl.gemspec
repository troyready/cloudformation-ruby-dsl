# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudformation-ruby-dsl/version'

Gem::Specification.new do |gem|
  gem.name          = "cloudformation-ruby-dsl"
  gem.version       = Cloudformation::Ruby::Dsl::VERSION
  gem.authors       = ["Dave Barcelo"]
  gem.email         = ["Dave.Barcelo@bazaarvoice.com"]
  gem.description   = %q{Ruby DSL library that provides a wrapper around the cfn-cmd.}
  gem.summary       = %q{Ruby DSL library that provides a wrapper around the cfn-cmd.  Written by [Bazaarvoice](http://www.bazaarvoice.com).}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
