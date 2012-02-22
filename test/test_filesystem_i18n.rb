# encoding: utf-8

require './test/helper'

class TestNanocFilesystemI18n < MiniTest::Unit::TestCase

  include Nanoc::TestHelpers

  def new_data_source(params=nil)
    # Mock site
    site = Nanoc::Site.new({})

    # Create data source
    data_source = Nanoc::DataSources::FilesystemI18n.new(site, nil, nil, params)
    data_source.up

    # Done
    data_source
  end

  def test_create_object_not_at_root
    # Create item
    data_source = new_data_source
    data_source.send(:create_object, 'foobar', 'content here', { :foo => 'bar' }, '/asdf/')

    # Check file existance
    assert File.directory?('foobar')
    assert !File.directory?('foobar/content')
    assert !File.directory?('foobar/asdf')
    assert File.file?('foobar/asdf.yaml')
    assert File.file?('foobar/asdf.html')

    # Check file meta
    expected = "---\nfoo: bar\n"
    assert_equal YAML.load(expected), YAML.load(File.read('foobar/asdf.yaml'))

    # Check file content
    expected = "content here"
    assert_equal expected, File.read('foobar/asdf.html')
  end

  def test_create_object_at_root
    # Create item
    data_source = new_data_source
    data_source.send(:create_object, 'foobar', 'content here', { :foo => 'bar' }, '/')

    # Check file existance
    assert File.directory?('foobar')
    assert !File.directory?('foobar/index')
    assert !File.directory?('foobar/foobar')
    assert File.file?('foobar/index.yaml')
    assert File.file?('foobar/index.html')

    # Check file meta
    expected = "---\nfoo: bar\n"
    assert_equal YAML.load(expected), YAML.load(File.read('foobar/index.yaml'))

    # Check file content
    expected = "content here"
    assert_equal expected, File.read('foobar/index.html')
  end

end
