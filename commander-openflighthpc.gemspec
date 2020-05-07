# -*- encoding: utf-8 -*-

$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'commander/version'

Gem::Specification.new do |s|
  s.name        = 'commander-openflighthpc'
  s.version     = Commander::VERSION
  s.authors     = ['Alces Flight Ltd', 'TJ Holowaychuk', 'Gabriel Gilder']
  s.email       = ['flight@openflighthpc.org']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/openflighthpc/commander-openflighthpc'
  s.summary     = 'The complete solution for Ruby command-line executables'
  s.description = 'The complete solution for Ruby command-line executables. Commander bridges the gap between other terminal related libraries you know and love (OptionParser, HighLine), while providing many new features, and an elegant API.'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency('highline', '> 1.7.2')
  s.add_runtime_dependency('slop', '~> 4.8')
  s.add_runtime_dependency('paint', '~> 2.1.0')

  s.add_development_dependency('rspec', '~> 3.2')
  s.add_development_dependency('rake')
  s.add_development_dependency('simplecov')
  if RUBY_VERSION < '2.0'
    s.add_development_dependency('rubocop', '~> 0.41.1')
    s.add_development_dependency('json', '< 2.0')
  else
    s.add_development_dependency('rubocop', '~> 0.49.1')
  end
end
