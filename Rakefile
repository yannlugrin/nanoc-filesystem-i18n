require 'bundler'
Bundler::GemHelper.install_tasks

begin
  require 'nanoc'
rescue LoadError # fallback to nanoc3 namespace
  require 'nanoc3'
  Nanoc = Nanoc3
end

require 'minitest/unit'

desc 'Run all tests'
task :test do
  ENV['QUIET'] ||= 'true'

  MiniTest::Unit.autorun

  test_files = Dir['./test/**/*_spec.rb'] + Dir['./test/**/test_*.rb']
  test_files.each { |f| require f }
end

task :default => :test

begin
  require 'nanoc'
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end
