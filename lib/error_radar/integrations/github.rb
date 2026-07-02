# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ErrorRadar
  module Integrations
    # Creates GitHub issues from ErrorLog records via the GitHub REST API.
    # Requires a personal access token with the `repo` scope and a repo in
    # "owner/repo" format.
    module Github
      API_BASE = 'https://api.github.com'

      # Returns the parsed JSON response from GitHub.
      # Raises StandardError on network/API failure.
      def self.create_issue(error_log, token:, repo:)
        owner, repo_name = repo.split('/', 2)
        uri  = URI("#{API_BASE}/repos/#{owner}/#{repo_name}/issues")

        http              = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.open_timeout = 10
        http.read_timeout = 10

        req = Net::HTTP::Post.new(uri)
        req['Authorization']        = "Bearer #{token}"
        req['Content-Type']         = 'application/json'
        req['Accept']               = 'application/vnd.github+json'
        req['X-GitHub-Api-Version'] = '2022-11-28'
        req.body = {
          title:  issue_title(error_log),
          body:   issue_body(error_log),
          labels: ['bug', 'error-radar']
        }.to_json

        response = http.request(req)
        JSON.parse(response.body)
      end

      def self.issue_title(log)
        short_msg = log.message.to_s.truncate(80).gsub(/\n/, ' ')
        "[Error Radar] #{log.error_class}: #{short_msg}"
      end

      def self.issue_body(log)
        url       = ErrorRadar::Notifier.error_url(log)
        backtrace = log.backtrace.to_s.split("\n").first(20).join("\n")

        parts = []
        parts << "## Error Details\n"
        parts << "| Field | Value |"
        parts << "|-------|-------|"
        parts << "| **Error Class** | `#{log.error_class}` |"
        parts << "| **Source** | #{log.source || 'unknown'} |"
        parts << "| **Category** | #{log.category} |"
        parts << "| **Severity** | #{log.severity} |"
        parts << "| **Occurrences** | #{log.occurrences} |"
        parts << "| **First seen** | #{log.first_seen_at&.strftime('%Y-%m-%d %H:%M UTC')} |"
        parts << "| **Last seen** | #{log.last_seen_at&.strftime('%Y-%m-%d %H:%M UTC')} |"
        parts << "\n## Message\n\n```\n#{log.message.to_s.truncate(1000)}\n```"

        unless backtrace.empty?
          parts << "\n## Backtrace\n\n```\n#{backtrace}\n```"
        end

        parts << "\n## Link\n\n[View in Error Radar](#{url})" if url

        parts << "\n---\n*Created automatically by [Error Radar](https://github.com/chienbn9x/error_radar)*"
        parts.join("\n")
      end
    end
  end
end
