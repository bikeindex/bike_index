if Rails.env.production?
  Dumper::Agent.start(:app_key => ENV['DUMPER_KEY'])
end
