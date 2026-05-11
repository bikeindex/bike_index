if ENV["LOCAL_CHROME_OVERRIDE"]
  # Re-register Capybara's :selenium_chrome_headless driver with flags needed
  # when Chrome runs as root inside a container (sandbox/dev environments).
  # No-op when LOCAL_CHROME_OVERRIDE is unset — CI and developer machines are
  # unaffected.
  Capybara.register_driver :selenium_chrome_headless do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-site-isolation-trials")
    options.add_argument("--ignore-certificate-errors")
    options.add_argument("--host-resolver-rules=MAP cdn.jsdelivr.net 127.0.0.1:8443")
    options.add_argument("--user-data-dir=/tmp/chrome-test-#{Process.pid}-#{rand(10_000)}")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
end
