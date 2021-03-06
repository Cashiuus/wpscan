# encoding: UTF-8

require 'web_site'
require 'wp_target/malwares'
require 'wp_target/wp_readme'
require 'wp_target/wp_registrable'
require 'wp_target/wp_config_backup'
require 'wp_target/wp_login_protection'
require 'wp_target/wp_custom_directories'
require 'wp_target/wp_full_path_disclosure'

class WpTarget < WebSite
  include WpTarget::Malwares
  include WpTarget::WpReadme
  include WpTarget::WpRegistrable
  include WpTarget::WpConfigBackup
  include WpTarget::WpLoginProtection
  include WpTarget::WpCustomDirectories
  include WpTarget::WpFullPathDisclosure

  attr_reader :verbose

  def initialize(target_url, options = {})
    super(target_url)

    @verbose        = options[:verbose]
    @wp_content_dir = options[:wp_content_dir]
    @wp_plugins_dir = options[:wp_plugins_dir]
    @multisite      = nil

    Browser.instance(options.merge(:max_threads => options[:threads]))
  end

  # check if the target website is
  # actually running wordpress.
  def wordpress?
    wordpress = false

    response = Browser.get_and_follow_location(@uri.to_s)

    if response.body =~ /["'][^"']*\/wp-content\/[^"']*["']/i
      wordpress = true
    else

      if has_xml_rpc?
        wordpress = true
      else
        response = Browser.get_and_follow_location(login_url)

        if response.code == 200 && response.body =~ %r{WordPress}i
          wordpress = true
        end
      end
    end

    wordpress
  end

  def wordpress_hosted?
    @uri.to_s =~ /\.wordpress\.com/i
  end

  def login_url
    url = @uri.merge('wp-login.php').to_s

    # Let's check if the login url is redirected (to https url for example)
    redirection = redirection(url)
    if redirection
      url = redirection
    end

    url
  end

  # Valid HTTP return codes
  def self.valid_response_codes
    [200, 301, 302, 401, 403, 500, 400]
  end

  # @return [ WpTheme ]
  # :nocov:
  def theme
    WpTheme.find(@uri)
  end
  # :nocov:

  # @param [ String ] versions_xml
  #
  # @return [ WpVersion ]
  # :nocov:
  def version(versions_xml)
    WpVersion.find(@uri, wp_content_dir, wp_plugins_dir, versions_xml)
  end
  # :nocov:

  # The version is not yet considerated
  #
  # @param [ String ] name
  # @param [ String ] version
  #
  # @return [ Boolean ]
  def has_plugin?(name, version = nil)
    WpPlugin.new(
      @uri,
      name: name,
      version: version,
      wp_content_dir: wp_content_dir,
      wp_plugins_dir: wp_plugins_dir
    ).exists?
  end

  # @return [ Boolean ]
  def has_debug_log?
    WebSite.has_log?(debug_log_url, %r{\[[^\]]+\] PHP (?:Warning|Error|Notice):})
  end

  # @return [ String ]
  def debug_log_url
    @uri.merge("#{wp_content_dir()}/debug.log").to_s
  end

  # Script for replacing strings in wordpress databases
  # reveals database credentials after hitting submit
  # http://interconnectit.com/124/search-and-replace-for-wordpress-databases/
  #
  # @return [ String ]
  def search_replace_db_2_url
    @uri.merge('searchreplacedb2.php').to_s
  end

  # @return [ Boolean ]
  def search_replace_db_2_exists?
    resp = Browser.get(search_replace_db_2_url)
    resp.code == 200 && resp.body[%r{by interconnect}i]
  end
end
