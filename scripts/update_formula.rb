#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "pathname"
require "tmpdir"
require "uri"

UPSTREAM_REPO = "router-for-me/Cli-Proxy-API-Management-Center"
FORMULA_PATH = Pathname.new(__dir__).join("../Formula/cliproxyapi-management-center.rb").expand_path

def github_get(url, redirects: 5, &block)
  raise "too many redirects for #{url}" if redirects.negative?

  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json"
  request["User-Agent"] = "homebrew-cliproxyapi-management-center-updater"
  if ENV["GITHUB_TOKEN"]&.length&.positive? && ["api.github.com", "github.com"].include?(uri.host)
    request["Authorization"] = "Bearer #{ENV.fetch("GITHUB_TOKEN")}"
  end

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request) do |response|
      case response
      when Net::HTTPSuccess
        return block.call(response)
      when Net::HTTPRedirection
        location = response["location"]
        raise "redirect without location for #{url}" if location.nil? || location.empty?

        return github_get(location, redirects: redirects - 1, &block)
      else
        raise "GET #{url} failed: #{response.code} #{response.message}"
      end
    end
  end
end

def fetch_json(url)
  github_get(url) { |response| JSON.parse(response.body) }
end

def download_to(url, path)
  github_get(url) do |response|
    File.open(path, "wb") do |file|
      response.read_body { |chunk| file.write(chunk) }
    end
  end
end

def asset_named(release, name)
  release.fetch("assets").find { |asset| asset.fetch("name") == name } ||
    raise("missing asset #{name} in #{release.fetch("html_url")}")
end

def sha256_for(asset)
  digest = asset["digest"].to_s
  return digest.delete_prefix("sha256:") if digest.start_with?("sha256:")

  Dir.mktmpdir do |dir|
    path = File.join(dir, asset.fetch("name"))
    download_to(asset.fetch("browser_download_url"), path)
    Digest::SHA256.file(path).hexdigest
  end
end

release = fetch_json("https://api.github.com/repos/#{UPSTREAM_REPO}/releases/latest")
tag = release.fetch("tag_name")
version = tag.delete_prefix("v")
asset = asset_named(release, "management.html")
sha256 = sha256_for(asset)

formula = <<~RUBY
  class CliproxyapiManagementCenter < Formula
    desc "Static Web UI for managing CLI Proxy API"
    homepage "https://github.com/#{UPSTREAM_REPO}"
    url "https://github.com/#{UPSTREAM_REPO}/releases/download/#{tag}/management.html",
        using: :nounzip
    version "#{version}"
    sha256 "#{sha256}"
    license "MIT"

    depends_on "python@3.14"

    livecheck do
      url "https://github.com/#{UPSTREAM_REPO}/releases/latest"
      strategy :github_latest
    end

    def install
      (share/"cliproxyapi-management-center").install "management.html"

      (bin/"cliproxyapi-management-center").write <<~EOS
        #!/bin/bash
        set -euo pipefail

        case "\${1:-}" in
          --version|-v)
            echo "#{version}"
            exit 0
            ;;
          --path)
            echo "\#{opt_share}/cliproxyapi-management-center/management.html"
            exit 0
            ;;
          --help|-h)
            cat <<'HELP'
        Usage: cliproxyapi-management-center [--port PORT]
               cliproxyapi-management-center --path
               cliproxyapi-management-center --version

        Serves the static CLI Proxy API Management Center UI on localhost.
        HELP
            exit 0
            ;;
        esac

        port="\${CLIPROXYAPI_MC_PORT:-5173}"
        if [[ "\${1:-}" == "--port" ]]; then
          if [[ -z "\${2:-}" ]]; then
            echo "missing value for --port" >&2
            exit 2
          fi
          port="$2"
          shift 2
        fi

        if [[ $# -gt 0 ]]; then
          echo "unknown argument: $1" >&2
          exit 2
        fi

        root="\#{opt_share}/cliproxyapi-management-center"
        url="http://127.0.0.1:\${port}/management.html"

        echo "Serving cliproxyapi-management-center #{version} at \${url}"
        echo "Press Ctrl-C to stop."
        command -v open >/dev/null 2>&1 && open "\${url}" >/dev/null 2>&1 || true
        cd "\${root}"
        exec "\#{Formula["python@3.14"].opt_bin}/python3" -m http.server "\${port}" --bind 127.0.0.1
      EOS
      chmod 0555, bin/"cliproxyapi-management-center"
    end

    def caveats
      <<~EOS
        Run the local panel with:
          cliproxyapi-management-center

        Or inspect the installed HTML path with:
          cliproxyapi-management-center --path
      EOS
    end

    test do
      assert_path_exists share/"cliproxyapi-management-center/management.html"
      assert_equal version.to_s, shell_output("\#{bin}/cliproxyapi-management-center --version").strip
    end
  end
RUBY

FileUtils.mkdir_p(FORMULA_PATH.dirname)
FORMULA_PATH.write(formula)
