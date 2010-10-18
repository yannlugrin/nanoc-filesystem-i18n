# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{nanoc-filesystem-i18n}
  s.version = "0.1.0.pre4"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Yann Lugrin"]
  s.date = %q{2010-10-18}
  s.description = %q{I18n filesystem based data source for nanoc. Compatible with nanoc 3 and default filesystem based data source.}
  s.email = %q{yann.lugrin@sans-savoir.net}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    "LICENSE",
     "README.rdoc",
     "Rakefile",
     "lib/nanoc3/data_sources/filesystem_i18n.rb",
     "lib/nanoc3/data_sources/filesystem_i18n/version.rb",
     "lib/nanoc3/extra/i18n.rb",
     "test/helper.rb",
     "test/test_filesystem.rb",
     "test/test_filesystem_i18n.rb",
     "test/test_filesystem_unified.rb",
     "test/test_filesystem_verbose.rb"
  ]
  s.homepage = %q{http://github.com/yannlugrin/nanoc-filesystem-i18n}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{I18n filesystem based data source for nanoc}
  s.test_files = [
    "test/helper.rb",
     "test/test_filesystem_unified.rb",
     "test/test_filesystem_i18n.rb",
     "test/test_filesystem.rb",
     "test/test_filesystem_verbose.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nanoc>, [">= 3.1.2"])
      s.add_runtime_dependency(%q<i18n>, [">= 0"])
      s.add_development_dependency(%q<minitest>, [">= 0"])
      s.add_development_dependency(%q<yard>, [">= 0"])
    else
      s.add_dependency(%q<nanoc>, [">= 3.1.2"])
      s.add_dependency(%q<i18n>, [">= 0"])
      s.add_dependency(%q<minitest>, [">= 0"])
      s.add_dependency(%q<yard>, [">= 0"])
    end
  else
    s.add_dependency(%q<nanoc>, [">= 3.1.2"])
    s.add_dependency(%q<i18n>, [">= 0"])
    s.add_dependency(%q<minitest>, [">= 0"])
    s.add_dependency(%q<yard>, [">= 0"])
  end
end

