# Custom (MyDesk): compares the gateway's version with Evolution API releases on GitHub, so Super Admin can
# show when a stable update is out or a new version is in testing. Results are cached for a few hours.
class WhatsappWeb::ReleaseCheck
  RELEASES_URL = 'https://api.github.com/repos/evolution-foundation/evolution-api/releases?per_page=20'.freeze
  CACHE_KEY = 'mydesk:whatsapp_web:releases'.freeze
  CACHE_TTL = 6.hours
  # From 2.4.0 every gateway must be activated against the Evolution Foundation licensing server
  LICENSED_FROM = Gem::Version.new('2.4.0')

  Release = Data.define(:version, :tag, :url, :published_at, :prerelease) do
    # `release` drops the pre-release part, so 2.4.0-rc2 counts as 2.4.0
    def requires_license? = version.release >= LICENSED_FROM
  end

  def self.refresh!
    Rails.cache.delete(CACHE_KEY)
  end

  attr_reader :error

  def initialize(current_version)
    @current = parse_version(current_version)
  end

  def current_version = @current

  def latest_stable
    releases.reject(&:prerelease).max_by(&:version)
  end

  # A release candidate newer than the latest stable one, if any
  def upcoming
    candidate = releases.select(&:prerelease).max_by(&:version)
    candidate if candidate && (latest_stable.nil? || candidate.version > latest_stable.version)
  end

  def update_available?
    @current.present? && latest_stable.present? && latest_stable.version > @current
  end

  def checked_at
    cached&.dig(:checked_at)
  end

  private

  def releases
    @releases ||= Array(cached&.dig(:releases)).map { |attrs| Release.new(**attrs, version: Gem::Version.new(attrs[:tag])) }
  end

  def cached
    @cached ||= Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_releases }
  rescue StandardError => e
    @error = e.message
    nil
  end

  def fetch_releases
    response = HTTParty.get(RELEASES_URL, headers: { 'User-Agent' => 'MyDesk', 'Accept' => 'application/vnd.github+json' },
                                          timeout: 8)
    raise "GitHub HTTP #{response.code}" unless response.success?

    releases = response.parsed_response.filter_map do |release|
      tag = release['tag_name'].to_s.delete_prefix('v')
      next unless Gem::Version.correct?(tag)

      { tag: tag, url: release['html_url'], published_at: release['published_at'], prerelease: release['prerelease'] }
    end
    { releases: releases, checked_at: Time.current }
  end

  def parse_version(value)
    Gem::Version.new(value.to_s) if Gem::Version.correct?(value.to_s) && value.present?
  end
end
