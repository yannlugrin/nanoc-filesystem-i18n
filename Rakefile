require 'bundler'
Bundler::GemHelper.install_tasks

require 'nanoc3'

require 'minitest/unit'

desc 'Run all tests'
task :test do
  ENV['QUIET'] ||= 'true'

  $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/test'))

  MiniTest::Unit.autorun

  test_files = Dir['test/**/*_spec.rb'] + Dir['test/**/test_*.rb']
  test_files.each { |f| require f }
end

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
