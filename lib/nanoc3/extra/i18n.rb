# encoding: utf-8

require 'nanoc3'
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
