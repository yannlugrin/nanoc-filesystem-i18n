require 'rubygems'
require 'rake'
require File.dirname(__FILE__) + '/lib/nanoc3/data_sources/version'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'nanoc-filesystem-i18n'
    gem.version = Nanoc3::DataSources::Version
    gem.summary = %Q{I18n filesystem based data source for nanoc}
    gem.description = %Q{I18n filesystem based data source for nanoc. Compatible with nanoc 3 and default filesystem based data source.}
    gem.email = 'yann.lugrin@sans-savoir.net'
    gem.homepage = 'http://github.com/yannlugrin/nanoc-filesystem-i18n'
    gem.authors = ['Yann Lugrin']
    gem.add_dependency 'nanoc', '>= 3.1.2'
    gem.add_dependency 'i18n', '>= 0'
    gem.add_development_dependency 'minitest', '>= 0'
    gem.add_development_dependency 'yard', '>= 0'
    gem.files.exclude '.gitignore', '.document'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

begin
  require 'nanoc3'
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end
