# frozen_string_literal: true

module ErrorRadar
  # Reads the live Sidekiq process registry from Redis and reports whether each
  # EXPECTED process (configured via ErrorRadar.config.expected_servers) is
  # currently alive. With no expectations configured it simply surfaces every
  # live process so the dashboard still shows something useful.
  #
  # Safe when Sidekiq is absent — every method degrades to empty results.
  class ServerMonitor
    DEAD_AFTER = 60 # seconds without a heartbeat => process considered gone

    Status = Struct.new(:key, :name, :up, :processes, :last_beat_ago, keyword_init: true)

    def self.statuses
      new.statuses
    end

    def expected
      ErrorRadar.config.expected_servers
    end

    def statuses
      live = live_processes

      if expected.empty?
        return live.map do |p|
          Status.new(
            key: p[:identity],
            name: "#{p[:hostname]} #{p[:tag]}".strip,
            up: p[:beat_ago] && p[:beat_ago] <= DEAD_AFTER,
            processes: [p],
            last_beat_ago: p[:beat_ago]
          )
        end
      end

      expected.map do |exp|
        matched = live.select { |p| matches?(p, exp) }
        Status.new(
          key: exp[:key],
          name: exp[:name],
          up: matched.any? { |p| p[:beat_ago] && p[:beat_ago] <= DEAD_AFTER },
          processes: matched,
          last_beat_ago: matched.map { |p| p[:beat_ago] }.compact.min
        )
      end
    end

    def unexpected_processes
      return [] if expected.empty?

      live_processes.reject { |p| expected.any? { |exp| matches?(p, exp) } }
    end

    def live_processes
      return [] unless defined?(::Sidekiq)

      require 'sidekiq/api'
      now = Time.now.to_f
      ::Sidekiq::ProcessSet.new.map do |p|
        {
          identity: p['identity'],
          hostname: p['hostname'],
          tag: p['tag'],
          queues: Array(p['queues']),
          concurrency: p['concurrency'],
          busy: p['busy'],
          rss: p['rss'],
          quiet: p['quiet'] == 'true' || p['quiet'] == true,
          started_at: p['started_at'] && Time.at(p['started_at']),
          beat_ago: p['beat'] ? (now - p['beat']).round : nil
        }
      end
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("ServerMonitor.live_processes failed: #{e.class}: #{e.message}")
      []
    end

    private

    def matches?(process, exp)
      return true if present?(exp[:tag]) && process[:tag].to_s == exp[:tag]
      return true if present?(exp[:host]) && process[:hostname].to_s.include?(exp[:host])

      present?(exp[:queue_hint]) && process[:queues].include?(exp[:queue_hint]) &&
        expected.none? { |o| o != exp && (process[:tag].to_s == o[:tag] || (present?(o[:host]) && process[:hostname].to_s.include?(o[:host].to_s))) }
    end

    def present?(value)
      !value.nil? && value != ''
    end
  end
end
