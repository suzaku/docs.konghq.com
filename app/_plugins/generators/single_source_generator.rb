# frozen_string_literal: true

module SingleSource
  class Generator < Jekyll::Generator
    priority :highest
    def generate(site) # rubocop:disable Metrics/AbcSize
      # Load versions data file
      @kong_versions = SafeYAML.load(File.read('app/_data/kong_versions.yml'))

      # Generate pages
      Dir.glob('app/_data/docs_nav_*.yml').each do |f|
        data = SafeYAML.load(File.read(f))
        next unless data.is_a?(Hash) && data['generate']

        # Assume that the whole file should be treated as generated
        assume_generated = data['assume_generated'].nil? ? true : data['assume_generated']
        version = version_for_release(data['product'], data['release'])
        create_pages(data['items'], site, data['product'], data['release'], version, assume_generated)
      end
    end

    def version_for_release(product, release)
      version = @kong_versions.detect do |v|
        v['edition'] == product && v['release'] == release
      end
      version['version']
    end

    def create_pages(data, site, product, release, version, assume_generated) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/ParameterLists
      data.each do |v, _k|
        # Enable generation of specific files as required
        next unless v['generate'] || assume_generated

        # Handle when it's the root page.
        # We always want to generate this, even if
        # it's an absolute_url
        v['src'] = 'index' if v['url'] == "/#{product}/" && !v['src']

        # Absolute URLs are expected to be generated by
        # another method, unless there's a 'src' set
        if (v['url'] && !v['absolute_url']) || v['src']
          # Is it an in-page link? If so, skip it
          next if v['url']&.include?('/#')

          site.pages << SingleSourcePage.new(site, v['src'], v['url'], product, release, version)
        end

        # If there are any children, generate those too
        create_pages(v['items'], site, product, release, version, assume_generated) if v['items']
      end
    end
  end

  class SingleSourcePage < Jekyll::Page
    def initialize(site, src, dest, product, release, version) # rubocop:disable Lint/MissingSuper, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/AbcSize, Metrics/ParameterLists
      # Configure variables that Jekyll depends on
      @site = site

      # Normalise the URL by removing the leading /
      dest = dest[1..] if dest[0] == '/'

      # If there's no 'src' key provided, assume it's the same as the url
      src ||= dest

      # Remove trailing slashes if they exist
      src = src.chomp('/')

      # Set self.ext and self.basename by extracting information from the page filename
      process('index.md')

      # We want to write to <url>
      output_path = dest
      output_path = '' if src == 'index'

      # This is the directory that we're going to write the output file to
      @dir = "#{product}/#{release}/#{output_path}"

      # If the src file doesn't start with a /, assume it's within the product folder
      # Otherwise, it's an absolute src path and we should start from /src
      src = "#{product}/#{src}" unless src[0] == '/'

      # Read the source file, either `<src>.md or <src>/index.md`
      file = "src/#{src}.md"
      file = "src/#{src}/index.md" unless File.exist?(file)
      content = File.read(file)

      # Load content + frontmatter from the file
      if content =~ Jekyll::Document::YAML_FRONT_MATTER_REGEXP
        @content = Regexp.last_match.post_match
        @data = SafeYAML.load(Regexp.last_match(1))
      end

      # Set the "Edit on GitHub" link url
      @data['edit_link'] = file

      # Set the current release and concrete version
      @data['release'] = release
      @data['version'] = version

      # Set the layout if it's not already provided
      @data['layout'] = 'docs-v2' unless data['layout']
    end
  end
end