group :red_green_refactor, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec', failed_mode: :focus do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^config/initializers/(.+)\.rb$})     { |m| "spec/initializers/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')  { "spec" }
    watch(%r{^app/controllers/api/v2/(.+)\.rb$})        { |m| "spec/api/v2/#{m[1]}_spec.rb"}
    watch(%r{^app/controllers/api/v3/(.+)\.rb$})        { |m| "spec/api/v3/#{m[1]}_spec.rb"}

    watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
    watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| "spec/controllers/#{m[1]}_#{m[2]}_spec.rb" }
    # watch(%r{^spec/support/(.+)\.rb$})                  { "spec" } # Stop running all specs on shared_example update
    watch('config/routes.rb')                           { "spec/routing" }
    watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  end

  guard :rubocop, all_on_start: false do
    watch(%r{^app/(.+)\.rb$})
    watch(%r{^spec/(.+)\.rb$})
    watch(%r{^config/(.+)\.rb$})
    watch(%r{^lib/(.+)\.rb$})
    watch(%r{^lib/(.+)\.rake$})
    watch(%r{^db/(.+)\.rb$})
    watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
  end
end