# frozen_string_literal: true

module ErrorRadar
  # Prunes stale ErrorLog records. Two independent strategies run in sequence:
  #
  #   1. Age-based: deletes resolved/ignored records whose last_seen_at is
  #      older than `older_than_days` (or config.retention_days).
  #   2. Count-based: when the total exceeds config.max_records, deletes the
  #      oldest resolved/ignored records until the limit is satisfied.
  #
  # Open and in_progress records are never deleted automatically.
  module Cleanup
    def self.run(older_than_days: nil, dry_run: false)
      deleted = 0

      # ── Age-based pruning ───────────────────────────────────────────────
      days = (older_than_days || ErrorRadar.config.retention_days)&.to_i
      if days && days > 0
        cutoff = days.days.ago
        scope  = stale_scope.where('last_seen_at < ?', cutoff)
        deleted += dry_run ? scope.count : scope.delete_all
      end

      # ── Count-based pruning ────────────────────────────────────────────
      max = ErrorRadar.config.max_records&.to_i
      if max && max > 0
        total = ErrorLog.count
        if total > max
          excess = total - max
          ids    = stale_scope.order(last_seen_at: :asc).limit(excess).pluck(:id)
          deleted += dry_run ? ids.size : ErrorLog.where(id: ids).delete_all
        end
      end

      { deleted: deleted, dry_run: dry_run }
    end

    def self.stale_scope
      ErrorLog.where(status: [ErrorLog.statuses[:resolved], ErrorLog.statuses[:ignored]])
    end
    private_class_method :stale_scope
  end
end
