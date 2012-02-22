# encoding: utf-8

begin
  require 'nanoc'
rescue LoadError # fallback to nanoc3 namespace
  require 'nanoc3'
  Nanoc = Nanoc3
end
require 'i18n'

module I18n
  class Config

    # A site is note localized if available locale is empty
    def localized_site?
      !available_locales.empty?
    end

  end

  class << self
    def localized_site?
      config.localized_site?
    end
  end
end
