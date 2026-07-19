# Homebrew CLIProxyAPI Management Center Tap

Personal Homebrew tap for [router-for-me/Cli-Proxy-API-Management-Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center).

## Install

```sh
brew tap aboutdomtime/cliproxyapi-management-center
brew install cliproxyapi-management-center
```

Run the static management panel locally:

```sh
cliproxyapi-management-center
```

Then open `http://127.0.0.1:5173/management.html`.

## Updating

`.github/workflows/update-formula.yml` checks the latest upstream GitHub release on a schedule and commits formula updates when a new release is available.
