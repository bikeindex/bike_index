if ENV["LOCAL_CHROME_OVERRIDE"]
  # Re-register the :playwright driver with the chromium flags needed when the
  # browser runs as root inside a container (sandbox/dev environments).
  # No-op when LOCAL_CHROME_OVERRIDE is unset — CI and developer machines are
  # unaffected.
  Capybara.register_driver :playwright do |app|
    PlaywrightDriver.new(app,
      browser_type: :chromium,
      headless: true,
      viewport: {width: 1920, height: 1080},
      ignoreHTTPSErrors: true,
      args: [
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-site-isolation-trials",
        "--host-resolver-rules=MAP cdn.jsdelivr.net 127.0.0.1:8443"
      ])
  end
end
