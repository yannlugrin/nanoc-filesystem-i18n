# encoding: utf-8

require 'nanoc3'
require 'i18n'

module I18n
  class Config

    def localized_site?
      !available_locales.empty?
    end

    def exclude_list(kind)
      @exclude ||= {}
      @exclude[kind] ||= localized_site? ? [] : ['*']
    end

    def exclude_list=(exclude)
      @exclude = exclude
    end

  end

  class << self
    def load_config(dir_or_config_hash)
      if dir_or_config_hash.is_a? String
        # Read config from config.yaml in given dir
        config_path = File.join(dir_or_config_hash, 'config.yaml')
        config_data = YAML.load_file(config_path).symbolize_keys[:locale] rescue {}
      else
        # Use passed config hash
        config_data = dir_or_config_hash || {}
      end

      config.available_locales = config_data[:availables] ? config_data[:availables].map {|code, data| code.to_sym } : []
      if I18n.localized_site?
        config.default_locale = begin config_data[:availables].find{|code, data| data[:default] }[0] rescue config_data[:availables].first[0] end
        config.exclude_list = config_data[:exclude]
      end
    end

    def exclude_list(kind)
      config.exclude_list(kind)
    end

    def localized_site?
      config.localized_site?
    end
  end
end
