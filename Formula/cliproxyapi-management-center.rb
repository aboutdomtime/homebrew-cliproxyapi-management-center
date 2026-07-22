class CliproxyapiManagementCenter < Formula
  desc "Static Web UI for managing CLI Proxy API"
  homepage "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"
  url "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.18.6/management.html",
      using: :nounzip
  version "1.18.6"
  sha256 "99440f294a02eddbb59311162c7f5eb3a724cd36342d897762eeacdc03259921"
  license "MIT"

  depends_on "python@3.14"

  livecheck do
    url "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/latest"
    strategy :github_latest
  end

  def install
    (share/"cliproxyapi-management-center").install "management.html"

    (bin/"cliproxyapi-management-center").write <<~EOS
      #!/bin/bash
      set -euo pipefail

      case "${1:-}" in
        --version|-v)
          echo "1.18.6"
          exit 0
          ;;
        --path)
          echo "#{opt_share}/cliproxyapi-management-center/management.html"
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

      port="${CLIPROXYAPI_MC_PORT:-5173}"
      if [[ "${1:-}" == "--port" ]]; then
        if [[ -z "${2:-}" ]]; then
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

      root="#{opt_share}/cliproxyapi-management-center"
      url="http://127.0.0.1:${port}/management.html"

      echo "Serving cliproxyapi-management-center 1.18.6 at ${url}"
      echo "Press Ctrl-C to stop."
      command -v open >/dev/null 2>&1 && open "${url}" >/dev/null 2>&1 || true
      cd "${root}"
      exec "#{Formula["python@3.14"].opt_bin}/python3" -m http.server "${port}" --bind 127.0.0.1
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
    assert_equal version.to_s, shell_output("#{bin}/cliproxyapi-management-center --version").strip
  end
end
