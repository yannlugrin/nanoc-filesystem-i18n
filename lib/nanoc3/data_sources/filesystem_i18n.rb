# encoding: utf-8

require 'i18n'

module Nanoc3::DataSources

  # The filesystem_i18n data source is a localized data source for a nanoc
  # site. It stores all data as files on the hard disk and is compatible with
  # defaults nanoc filesystem data source.
  #
  # None of the public api methods are documented in this file. See
  # {Nanoc3::DataSource} for documentation on the overridden methods instead.
  #
  # The filesystem_i18n data source stores its items and layouts in nested
  # directories or files. Each directory represents a single item or layout,
  # but an item can be a single file a in directory.The root directory for
  # items is the `content` directory; for layouts it is the `layouts`
  # directory.
  #
  # Every directory has a content file and a meta file. The content file
  # contains the actual item content or layout, while the meta file contains
  # the item’s or the layout’s metadata, formatted as YAML.
  #
  # Both content files and meta files are named after its parent directory
  # (i.e. item). For example, an item/layout named `foo` will have a directory
  # named `foo`, with e.g. a `foo.markdown` or `index.markdown` content file
  # and a `foo.yaml` or `index.yaml` meta file. An item/layout named `foo/bar`
  # can be also created in parent directory named `foo` without dedicated
  # directory, with e.g. a `foo.markdown` content file and `foo.yaml` meta
  # file.
  #
  # Content file extensions are not used for determining the filter that
  # should be run; the meta file defines the list of filters. The meta file
  # extension must always be `.yaml`, though.
  #
  # An item/layout content file named `foo.markdown` contain default content
  # for all locales, but you can create a content file for each locales with
  # e.g. a `foo.fr.markdown` for locale `fr`. If default locale for site is
  # `fr`, the `foo.fr.markdow` file is the default content file and the
  # `foo.markdown` file must be deleted.
  #
  # The identifier is calculated by stripping the extension (part after last dot)
  # and locale code.
  class FilesystemI18n < Nanoc3::DataSource
    identifier :filesystem_i18n

    # The VCS that will be called when adding, deleting and moving files. If
    # no VCS has been set, or if the VCS has been set to `nil`, a dummy VCS
    # will be returned.
    #
    # @return [Nanoc3::Extra::VCS, nil] The VCS that will be used.
    def vcs
      @vcs ||= Nanoc3::Extra::VCSes::Dummy.new
    end
    attr_writer :vcs

    # See {Nanoc3::DataSource#up}.
    def up
      if !@locale_config
        # Default empty config for nanoc filesystem data source compatibility
        @config[:locale]              ||= {}
        @config[:locale][:availables] ||= {}

        # Load locale config
        @locale_config = @config[:locale].symbolize_keys

        # Configure I18n module with default value callback
        I18n.default_locale = begin @locale_config[:availables].find{|code, data| data[:default] }[0] rescue :en end
        I18n.available_locales = @locale_config[:availables].empty? ? [I18n.default_locale] : @locale_config[:availables].map {|code, data| code.to_sym }
      end
    end

    # See {Nanoc3::DataSource#down}.
    def down
      @locale_config = nil
    end

    # See {Nanoc3::DataSource#setup}.
    def setup
      # Create directories
      %w( content layouts lib locale ).each do |dir|
        FileUtils.mkdir_p(dir)
        vcs.add(dir)
      end
    end

    # See {Nanoc3::DataSource#items}.
    def items
      load_objects('content', 'item', Nanoc3::Item)
    end

    # See {Nanoc3::DataSource#layouts}.
    def layouts
      load_objects('layouts', 'layout', Nanoc3::Layout)
    end

    # See {Nanoc3::DataSource#create_item}.
    def create_item(content, attributes, identifier, params={})
      create_object('content', content, attributes, identifier, params)
    end

    # See {Nanoc3::DataSource#create_layout}.
    def create_layout(content, attributes, identifier, params={})
      create_object('layouts', content, attributes, identifier, params)
    end

  private

    # Creates a new object (item or layout) on disk in dir_name according to
    # the given identifier. The file will have its attributes taken from the
    # attributes hash argument and its content from the content argument.
    def create_object(dir_name, content, attributes, identifier, params={})
      # Determine base path
      last_component = identifier.split('/')[-1] || dir_name
      base_path = dir_name + identifier + last_component

      # Get filenames
      ext = params[:extension] || '.html'
      dir_path          = dir_name + identifier
      meta_filename     = dir_name + identifier + last_component + '.yaml'
      content_filenames = {}
      i18n.available_locales.each do |locale|
        content_filenames[locale] = dir_name + identifier + last_component + ".#{locale}" + ext
      end

      # Notify
      Nanoc3::NotificationCenter.post(:file_created, meta_filename)
      content_filenames.each_value do |content_filename|
        Nanoc3::NotificationCenter.post(:file_created, content_filename)
      end

      # Create files
      FileUtils.mkdir_p(dir_path)
      File.open(meta_filename,    'w') { |io| io.write(YAML.dump(attributes.stringify_keys)) }
      content_filenames.each_value do |content_filename|
        File.open(content_filename, 'w') { |io| io.write(content) }
      end
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

        # Is binary content?
        is_binary = !!(content_filename && !@site.config[:text_extensions].include?(File.extname(content_filename)[1..-1]))

        # Read content and metadata
        meta, content_or_filename = parse(content_filename, meta_filename, kind, is_binary)

        # Is locale content?
        # - excluded content with locale meta IS a locale content
        # - excluded content without locale meta IS NOT locale content
        # - included content with or without locale meta IS locale content
        # - included content with locale meta set to `false` IS NOT locale
        #   content
        is_locale = !!(meta['locale'] || (meta['locale'] != false && locale_content?(content_filename, kind)))

        # Create one item by locale, if content don't need a localized version,
        # use default locale
        (is_locale ? I18n.available_locales : [I18n.default_locale]).map do |locale|
          I18n.locale = locale # Set current locale

          # Read content and metadata (only if is localized, default is already
          # loaded)
          meta, content_or_filename = parse(content_filename, meta_filename, kind, is_binary) if is_locale

          # merge meta for current locale, default locale meta used by
          # default is meta don't have key
          if is_locale
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
            :locale           => locale
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
        if !( 0 .. I18n.available_locales.size ).include?(content_filenames.size)
          raise RuntimeError, "Found #{content_filenames.size} content files for #{key}; expected 0 to #{I18n.available_locales.size}"
        end

        # Check content file extensions and default file
        if fn = content_filenames.find {|fn| ext_of(fn) != ext_of(content_filenames[0]) }
          raise RuntimeError, "Found multiple content extensions for `#{basename_of(fn)}.???`"
        end
        if !content_filenames.find {|fn| locale_of(fn) == I18n.default_locale } && !content_filenames.find {|fn| fn == basename_of(fn) + ext_of(fn) }
          raise RuntimeError, "Don't found default content file or default locale content file for `#{basename_of(content_filenames[0])}#{ext_of(content_filenames[0])}`"
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
      Regexp.union(@locale_config[:exclude][kind.to_sym].map do |identifier|
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

