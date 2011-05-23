# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)
require 'nanoc3/data_sources/filesystem_i18n/version'

Gem::Specification.new do |s|
  s.name        = 'nanoc-filesystem-i18n'
  s.version     = Nanoc3::DataSources::FilesystemI18nVersion
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Yann Lugrin']
  s.email       = ['yann.lugrin@sans-savoir.net']
  s.homepage    = 'http://rubygems.org/gems/nanoc-filesystem-i18n'
  s.summary     = 'I18n filesystem based data source for nanoc'
  s.description = 'I18n filesystem based data source for nanoc. Compatible with nanoc 3 and default filesystem based data source.'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project         = 'nanoc-filesystem-i18n'

  s.add_dependency 'nanoc', '>= 3.1.2'
  s.add_dependency 'i18n',  '>= 0.4.1'

  s.add_development_dependency 'minitest',  '>= 1.7.2'
  s.add_development_dependency 'mocha',     '>= 0.9.8'

  s.files        = Dir.glob('{lib}/**/*') + %w[LICENSE README.rdoc]
  s.require_path = 'lib'

  s.rdoc_options = ['--charset=UTF-8', '--main=README.rdoc', "--exclude='(lib|test|spec)|(Gem|Guard|Rake)file'"]
end
