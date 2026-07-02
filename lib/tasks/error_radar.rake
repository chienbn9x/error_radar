# frozen_string_literal: true

namespace :error_radar do
  desc 'Delete old resolved/ignored ErrorLogs per config.retention_days and config.max_records'
  task cleanup: :environment do
    result = ErrorRadar::Cleanup.run
    puts "[ErrorRadar] Cleanup complete — #{result[:deleted]} record(s) deleted."
  end

  namespace :cleanup do
    desc 'Preview what error_radar:cleanup would delete without actually deleting'
    task dry_run: :environment do
      result = ErrorRadar::Cleanup.run(dry_run: true)
      puts "[ErrorRadar] Dry run — would delete #{result[:deleted]} record(s)."
    end

    desc 'Delete resolved/ignored ErrorLogs older than DAYS (e.g. DAYS=30 rake error_radar:cleanup:older_than)'
    task older_than: :environment do
      days = ENV.fetch('DAYS', nil)&.to_i
      abort '[ErrorRadar] Set DAYS env var (e.g. DAYS=30)' unless days&.positive?

      result = ErrorRadar::Cleanup.run(older_than_days: days)
      puts "[ErrorRadar] Deleted #{result[:deleted]} record(s) older than #{days} days."
    end
  end

  desc 'Print a summary of ErrorLog table stats'
  task stats: :environment do
    counts = ErrorRadar::ErrorLog.group(:status).count
                                 .transform_keys { |k| ErrorRadar::ErrorLog.statuses.key(k) || k }
    total  = counts.values.sum

    puts "\n[ErrorRadar] Error log summary"
    puts "  Total      : #{total}"
    puts "  Open       : #{counts['open'] || 0}"
    puts "  In progress: #{counts['in_progress'] || 0}"
    puts "  Resolved   : #{counts['resolved'] || 0}"
    puts "  Ignored    : #{counts['ignored'] || 0}"

    oldest = ErrorRadar::ErrorLog.minimum(:first_seen_at)
    puts "  Oldest     : #{oldest&.strftime('%Y-%m-%d') || '—'}"
    puts ''
  end
end
