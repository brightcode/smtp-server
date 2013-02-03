# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smtp/server/version'

Gem::Specification.new do |gem|
  gem.name          = "smtp-server"
  gem.version       = SMTP::Server::VERSION
  gem.authors       = ["Maarten Oelering"]
  gem.email         = ["maarten@brightcode.nl"]
  gem.description   = %q{Framework independent SMTP server protocol handler}
  gem.summary       = %q{Framework independent SMTP server protocol handler}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
