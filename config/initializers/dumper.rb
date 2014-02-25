Dumper::Agent.start_if(:app_key => ENV['DUMPER_KEY']) do
  Rails.env.production? && dumper_enabled_host?
end