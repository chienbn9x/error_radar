# frozen_string_literal: true

module ErrorRadar
  # Detects sudden error-rate spikes for a given fingerprint.
  #
  # Strategy (in order of preference):
  #   1. If track_occurrences is on — query error_radar_occurrences for exact
  #      count in the window. Accurate across processes and survives restarts.
  #   2. In-memory ring buffer per fingerprint. Fast, zero extra DB queries, but
  #      resets on process restart and is per-worker (not shared across Puma workers).
  module SpikeDetector
    MUTEX = Mutex.new
    # fingerprint => Array<Time> of recent hit timestamps (in-memory fallback)
    HITS = Hash.new { |h, k| h[k] = [] }
    # Cap per-key buffer to avoid unbounded growth on very high-volume errors
    MAX_HITS_PER_KEY = 1000

    # Record a hit in the in-memory ring buffer.
    # Called by Notifier before spike detection so the current hit is counted.
    def self.record_hit(fingerprint)
      MUTEX.synchronize do
        arr = HITS[fingerprint]
        arr << Time.current
        arr.shift while arr.size > MAX_HITS_PER_KEY
      end
    end

    # Returns the number of recent hits if >= config threshold, false otherwise.
    def self.check(log)
      threshold = ErrorRadar.config.spike_threshold.to_i
      window    = ErrorRadar.config.spike_window_minutes.to_i
      return false unless threshold > 0 && window > 0

      count = recent_count(log, window)
      count >= threshold ? count : false
    end

    class << self
      private

      def recent_count(log, window_minutes)
        if ErrorRadar.config.track_occurrences && defined?(ErrorRadar::ErrorOccurrence)
          begin
            return ErrorRadar::ErrorOccurrence
                     .where(error_log_id: log.id)
                     .where('occurred_at >= ?', window_minutes.minutes.ago)
                     .count
          rescue ActiveRecord::StatementInvalid
            # Table not yet created — fall through to in-memory
          end
        end

        cutoff = window_minutes.minutes.ago
        MUTEX.synchronize do
          (HITS[log.fingerprint] || []).count { |t| t >= cutoff }
        end
      end
    end
  end
end
