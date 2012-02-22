# encoding: utf-8

begin
  require 'nanoc'
rescue LoadError # fallback to nanoc3 namespace
  require 'nanoc3'
  Nanoc = Nanoc3
end
require 'nanoc/extra/i18n'

module Nanoc::DataSources

  # The filesystem_i18n data source is a localized data source for a nanoc
  # site. It stores all data as files on the hard disk and is fully compatible
  # with {Nanoc::DataSources::FilesystemUnified} and {Nanoc::DataSources::FilesystemVerbose}.
  #
  # None of the public api methods are documented in this file. See
  # {Nanoc::DataSource} for documentation on the overridden methods instead.
  #
  # For more information about this data source specifications and configuration,
  # please read the Readme file.
  class FilesystemI18n < Nanoc::DataSource
    identifier :filesystem_i18n

    # The VCS that will be called when adding, deleting and moving files. If
    # no VCS has been set, or if the VCS has been set to `nil`, a dummy VCS
    # will be returned.
    #
    # @return [Nanoc::Extra::VCS, nil] The VCS that will be used.
    def vcs
      @vcs ||= Nanoc::Extra::VCSes::Dummy.new
    end
    attr_writer :vcs

    # See {Nanoc::DataSource#up}.
    def up
      load_config(@config)
    end

    # See {Nanoc::DataSource#down}.
    def down
      @config_loaded = false
    end

    # See {Nanoc::DataSource#setup}.
    def setup
      # Create directories
      %w( content layouts lib ).each do |dir|
        FileUtils.mkdir_p(dir)
        vcs.add(dir)
      end
    end

    # See {Nanoc::DataSource#items}.
    def items
      load_objects('content', 'item', Nanoc::Item)
    end

    # See {Nanoc::DataSource#layouts}.
    def layouts
      load_objects('layouts', 'layout', Nanoc::Layout)
    end

    # See {Nanoc::DataSource#create_item}.
    def create_item(content, attributes, identifier, params={})
      create_object('content', content, attributes, identifier, params)
    end

    # See {Nanoc::DataSource#create_layout}.
    def create_layout(content, attributes, identifier, params={})
      create_object('layouts', content, attributes, identifier, params)
    end

  private

    # Load data source configuration and configure I18n
    def load_config(config)
      unless @config_loaded
        config = config.symbolize_keys if config
        @exclude_objects = {}

        if config && config[:locale]
          I18n.available_locales = config[:locale][:availables] ? config[:locale][:availables].map {|code, data| code.to_sym } : []
          if I18n.localized_site?
            I18n.default_locale = I18n.available_locales.find{|code, data| data[:default] }[0] rescue I18n.available_locales.first
            @exclude_objects = config[:locale][:exclude] if config[:locale][:exclude]
          end
        end

        # By default, exclude object Hash return empty array, or if site
        # is not localized (no available locale), all objects is excluded.
        @exclude_objects.default = I18n.localized_site? ? [] : ['*']
      end

      @config_loaded = true
    end

    # Creates a new object (item or layout) on disk in dir_name according to
    # the given identifier. The file will have its attributes taken from the
    # attributes hash argument and its content from the content argument.
    def create_object(dir_name, content, attributes, identifier, params={})
      # Check for periods
      if (@config.nil? || !@config[:allow_periods_in_identifiers]) && identifier.include?('.')
        raise RuntimeError,
          "Attempted to create an object in #{dir_name} with identifier #{identifier} containing a period, but allow_periods_in_identifiers is not enabled in the site configuration. (Enabling allow_periods_in_identifiers may cause the site to break, though.)"
      end

      # Get filenames
      ext = params[:extension] || '.html'
      meta_filename    = dir_name + (identifier == '/' ? '/index.yaml' : identifier[0..-2] + '.yaml')
      content_filename = dir_name + (identifier == '/' ? '/index.html' : identifier[0..-2] + ext)
      parent_path = File.dirname(meta_filename)

      # Notify
      Nanoc::NotificationCenter.post(:file_created, meta_filename)
      Nanoc::NotificationCenter.post(:file_created, content_filename)

      # Create files
      FileUtils.mkdir_p(parent_path)
      File.open(meta_filename,    'w') { |io| io.write(YAML.dump(attributes.stringify_keys)) }
      File.open(content_filename, 'w') { |io| io.write(content) }
    end

    # Creates instances of klass corresponding to the files in dir_name. The
    # kind attribute indicates the kind of object that is being loaded and is
    # used solely for debugging purposes.
    #
    # This particular implementation loads objects from a filesystem-based
    # data source where content and attributes can be spread over two separate
    # files (one for metadata, with `yaml` extension, and one or more for content
    # with same extension and locale code before extension, separated by dot. A
    # content for default locale is used by default if file without locale code
    # is not present.
    #
    # The contents and meta-file are optional (but at least one of them needs
    # to be present, obviously. If a content file is present, file without locale
    # code or with default locale code is needed) and the content file can start
    # with a metadata section (if no metadata file is present).
    def load_objects(dir_name, kind, klass)
      all_split_files_in(dir_name).map do |base_filename, (meta_ext, content_ext, locales)|
        I18n.locale = I18n.default_locale # Set current locale to default

        # Get filenames
        meta_filename    = filename_for(base_filename, meta_ext)
        content_filename = filename_for(base_filename, content_ext)

        # is binary content?
        is_binary = !!(content_filename && !@site.config[:text_extensions].include?(File.extname(content_filename)[1..-1]))

        # Read content and metadata
        meta, content_or_filename = parse(content_filename, meta_filename, kind, (is_binary && klass == Nanoc::Item))

        # Is locale content?
        # - excluded content with locale meta IS a locale content
        # - excluded content without locale meta IS NOT locale content
        # - included content with or without locale meta IS locale content
        # - included content with locale meta set to `false` IS NOT locale
        #   content
        is_locale = !!(meta['locale'] || (meta['locale'] != false && locale_content?(content_filename || meta_filename, kind)))

        # Create one item by locale, if content don't need a localized version,
        # use default locale
        (is_locale ? I18n.available_locales : [I18n.default_locale]).map do |locale|
          I18n.locale = locale # Set current locale

          # Process for localized files
          if is_locale
            # Get filenames for localized content
            meta_filename    = filename_for(base_filename, meta_ext)
            content_filename = filename_for(base_filename, content_ext)

            # Read content and metadata for localized content
            meta, content_or_filename = parse(content_filename, meta_filename, kind, (is_binary && klass == Nanoc::Item))

            # merge meta for current locale, default locale meta used by
            # default is meta don't have key
            meta_locale = meta.delete('locale') {|el| Hash.new }
            meta = (meta_locale[I18n.default_locale] || Hash.new).merge(meta)
            meta.merge!(meta_locale[locale.to_s] || Hash.new)
          end

          # Get attributes
          attributes = {
            :filename         => content_filename,
            :content_filename => content_filename,
            :meta_filename    => meta_filename,
            :extension        => content_filename ? ext_of(content_filename)[1..-1] : nil,
            :locale           => locale,
            # WARNING :file is deprecated; please create a File object manually
            # using the :content_filename or :meta_filename attributes.
            # TODO [in nanoc 4.0] remove me
            :file             => content_filename ? Nanoc::Extra::FileProxy.new(content_filename) : nil
          }.merge(meta)

          # Get identifier
          if meta_filename
            identifier = identifier_for_filename(meta_filename[(dir_name.length+1)..-1])
          elsif content_filename
            identifier = identifier_for_filename(content_filename[(dir_name.length+1)..-1])
          else
            raise RuntimeError, "meta_filename and content_filename are both nil"
          end
          # Prepend locale code to identifier if content is localized
          identifier = "/#{locale}#{identifier}" if is_locale

          # Get modification times
          meta_mtime    = meta_filename    ? File.stat(meta_filename).mtime    : nil
          content_mtime = content_filename ? File.stat(content_filename).mtime : nil
          if meta_mtime && content_mtime
            mtime = meta_mtime > content_mtime ? meta_mtime : content_mtime
          elsif meta_mtime
            mtime = meta_mtime
          elsif content_mtime
            mtime = content_mtime
          else
            raise RuntimeError, "meta_mtime and content_mtime are both nil"
          end

          # Create layout object
          klass.new(
            content_or_filename, attributes, identifier,
            :binary => is_binary, :mtime => mtime
          )
        end
      end.flatten # elements is an array with all locale item, flatten in to one items list
    end

    # Finds all items/layouts/... in the given base directory. Returns a hash
    # in which the keys are the file's dirname + basenames, and the values is
    # an array with three elements: the metafile extension, the content file
    # extension and an array with locales of content file. The meta file
    # extension or the content file extension can be, but not both. Backup
    # files are ignored. For example:
    #
    #   {
    #     'content/foo' => [ 'yaml', 'html', ['en', 'fr'] ],
    #     'content/bar' => [ 'yaml',  nil  , [] ],
    #     'content/qux' => [ nil,    'html', ['en'] ]
    #   }
    def all_split_files_in(dir_name)
      # Get all good file names
      filenames = Dir[dir_name + '/**/*'].select { |i| File.file?(i) }
      filenames.reject! { |fn| fn =~ /(~|\.orig|\.rej|\.bak)$/ }

      # Group by identifier
      grouped_filenames = filenames.group_by { |fn| basename_of(fn).gsub('/index', '') }

      # Convert values into metafile/content file extension tuple
      grouped_filenames.each_pair do |key, filenames|
        # Divide
        meta_filenames    = filenames.select { |fn| ext_of(fn) == '.yaml' }
        content_filenames = filenames.select { |fn| ext_of(fn) != '.yaml' }

        # Check number of files per type
        if ![ 0, 1 ].include?(meta_filenames.size)
          raise RuntimeError, "Found #{meta_filenames.size} meta files for #{key}; expected 0 or 1"
        end
        if !( 0 .. (I18n.available_locales.empty? ? 1 : I18n.available_locales.size) ).include?(content_filenames.size)
          raise RuntimeError, "Found #{content_filenames.size} content files for #{key}; expected 0 to #{I18n.available_locales.size}"
        end

        # Check content file extensions and default file
        if fn = content_filenames.find {|fn| ext_of(fn) != ext_of(content_filenames[0]) }
          raise RuntimeError, "Found multiple content extensions for `#{basename_of(fn)}.???`"
        end

        # Reorder elements and convert to extnames
        filenames[0] = meta_filenames[0]    ? ext_of(meta_filenames[0])[1..-1]    : nil
        filenames[1] = content_filenames[0] ? ext_of(content_filenames[0])[1..-1] : nil
        filenames[2] = []
        content_filenames.each do |content_filename|
          filenames[2] << locale_of(content_filename) if locale_of(content_filename)
        end
      end

      # Done
      grouped_filenames
    end

    # Returns the filename for the given base filename, current locale (or
    # default locale) and the extension.
    #
    # If the extension is nil, this function should return nil as well.
    #
    # This implementation is compatible with simple file item and directory
    # item (with index or named file), find order is directory with named
    # file, directory with index file and simple file. For locale, find
    # order is current locale file, without locale file and default locale
    # file.
    #
    # Item priority order:
    # /foo/foo.html
    # /foo/index.html
    # /foo.html
    #
    # Locale priority order:
    # /foo/foo.{current locale}.html
    # /foo/foo.html
    # /foo/foo.{default locale}.html
    #
    def filename_for(base_filename, ext)
      last_part = base_filename.split('/')[-1]
      lang_part = "{.#{I18n.locale},,.#{I18n.default_locale}}"
      base_glob = base_filename.split('/')[0..-2].join('/') + "{/,}#{last_part}{/index,}#{lang_part}."

      ext ? Dir[base_glob + ext][0] : nil
    end

    # Returns the identifier that corresponds with the given filename, which
    # can be the content filename or the meta filename.
    def identifier_for_filename(filename)
      # Item is a directory with an index file
      if filename =~ /index(\.[a-z]{2})?\.[^\/]+$/
        regex = ((@config && @config[:allow_periods_in_identifiers]) ? /index(\.[a-z]{2})?(\.[^\/\.]+)$/        : /index(\.[a-z]{2})?(\.[^\/]+)$/)
      # Item is a directory with a named file
      elsif basename_of(filename).split(/\//)[-1] == basename_of(filename).split(/\//)[-2]
        regex = ((@config && @config[:allow_periods_in_identifiers]) ? /(\/[^\/]+)?(\.[a-z]{2})?(\.[^\/\.]+)$/  : /(\/[^\/]+)?(\.[a-z]{2})?(\.[^\/]+)$/)
      # Item is a simple file
      else
        regex = ((@config && @config[:allow_periods_in_identifiers]) ? /(\.[a-z]{2})?(\.[^\/\.]+)$/  : /(\.[a-z]{2})?(\.[^\/]+)$/)
      end

      filename.sub(regex, '').cleaned_identifier
    end

    # Returns the base name of filename, i.e. filename with the first or all
    # extensions stripped off. By default, all extensions are stripped off,
    # but when allow_periods_in_identifiers is set to true in the site
    # configuration, only the last extension will be stripped .
    def basename_of(filename)
      filename.sub(extension_regex, '')
    end

    # Returns the extension(s) of filename. Supports multiple extensions.
    # Includes the leading period. Return empty string if don't found
    # extension.
    def ext_of(filename)
      filename =~ extension_regex ? $2 : ''
    end

    # Returns a regex that is used for determining the extension of a file
    # name. The first match group will be the locale code (with leading
    # period) if exist and the second match group is entire extension,
    # including the leading period.
    def extension_regex
      if @config && @config[:allow_periods_in_identifiers]
        /(\.[a-z]{2})?(\.[^\/\.]+$)/
      else
        /(\.[a-z]{2})?(\.[^\/]+$)/
      end
    end

    # Returnes the locale code of filename or nil if filename is the default
    # file (without locale code).
    def locale_of(filename)
      locale = (filename =~ extension_regex ? $1 : nil)
      locale ? locale.gsub(/^\./, '').to_sym : nil
    end

    # Returnes true if this content is localized (based on data source config)
    def locale_content?(base_filename_or_identifier, kind)
      base_filename_or_identifier =~ locale_exclude_regex(kind) ? false : true
    end

    # Returnes regex that is used for determing if content is excluded not
    # localized (layouts, css, js, ...).
    #
    # Add to locale config follwing keys (exemple):
    #   exclude:
    #     item: ['/css*', '/js*']
    #     layout: ['*']
    #
    def locale_exclude_regex(kind)
      Regexp.union(@exclude_objects[kind.to_sym].map do |identifier|
        if identifier.is_a? String
          # Add leading/trailing slashes if necessary
          new_identifier = identifier.dup
          new_identifier[/^/] = '/' if identifier[0,1] != '/'
          new_identifier[/$/] = '/' unless [ '*', '/' ].include?(identifier[-1,1])

          /^[^\/]*#{new_identifier.gsub('*', '(.*?)').gsub('+', '(.+?)')}$/
        else
          identifier
        end
      end)
    end

    # Parses the file named `filename` and returns an array with its first
    # element a hash with the file's metadata, and with its second element the
    # file content itself.
    def parse(content_filename, meta_filename, kind, is_binary)
      # Read content and metadata from separate files
      if meta_filename || is_binary
        meta = (meta_filename && YAML.load_file(meta_filename)) || {}

        if is_binary
          content = content_filename
        else
          content = content_filename ? File.read(content_filename) : ''
        end

        return [ meta, content ]
      end

      # Read data
      data = File.read(content_filename)

      # Check presence of metadata section
      if data !~ /^(-{5}|-{3})/
        return [ {}, data ]
      end

      # Split data
      pieces = data.split(/^(-{5}|-{3})/)
      if pieces.size < 4
        raise RuntimeError.new(
          "The file '#{content_filename}' does not seem to be a nanoc #{kind}"
        )
      end

      # Parse
      meta    = YAML.load(pieces[2]) || {}
      content = pieces[4..-1].join.strip

      # Done
      [ meta, content ]
    end

  end
end

