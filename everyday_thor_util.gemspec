# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'everyday_thor_util/version'

Gem::Specification.new do |spec|
  spec.name        = 'everyday_thor_util'
  spec.version     = EverydayThorUtil::VERSION
  spec.authors     = ['Eric Henderson']
  spec.email       = ['henderea@gmail.com']
  spec.summary     = %q{Two parts: everyday_thor_util/thor-fix has a patch for Thor and everyday_thor_util/plugin-helper has some Thor handling everyday-plugin helpers}
  spec.description = %q{Two parts: everyday_thor_util/thor-fix patches Thor with a fix for help messages with multi-level command nesting not showing the full command string. everyday_thor_util/plugin-helper provides everyday-plugins types for Thor commands and Thor flags}
  spec.homepage    = 'https://github.com/henderea/everyday_thor_util'
  spec.license     = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.4'

  spec.add_dependency 'everyday-plugins', '~> 1.2'
  spec.add_dependency 'thor', '~> 0.19'
end
