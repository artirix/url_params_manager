# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'url_params_manager/version'

Gem::Specification.new do |spec|
  spec.name          = 'url_params_manager'
  spec.version       = UrlParamsManager::VERSION
  spec.authors       = ['Eduardo Turiño', 'Reuben Sutton']
  spec.email         = ['eturino@eturino.com', 'reuben.sutton@gmail.com']

  spec.summary       = %q{Allows SEO Friendly urls for search pages to be built easily. Intended to be used with Rails.}
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = 'https://github.com/artirix/url_params_manager'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  # end

  spec.add_dependency 'activesupport', '~> 4'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-given'
  spec.add_development_dependency 'rspec-nc'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-nav'
  spec.add_development_dependency 'pry-rescue'
  spec.add_development_dependency 'pry-stack_explorer'
  spec.add_development_dependency 'pry-doc'
end
