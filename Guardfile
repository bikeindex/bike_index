directories %w[app spec lib config]

group :red_green_refactor, halt_on_fail: true do
  rspec_options = {
    cmd: "bin/rspec -f progress",
    cmd_additional_args: "--require rails_helper --no-profile --order defined",
    run_all: {
      cmd: "bin/parallel_rspec --quiet --test-options='-f documentation -o /dev/null -f progress",
      cmd_additional_args: "'"
    },
    failed_mode: :focus,
    all_after_pass: false
  }

  guard :rspec, rspec_options do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$}) { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^config/initializers/(.+)\.rb$}) { |m| "spec/initializers/#{m[1]}_spec.rb" }

    watch("spec/spec_helper.rb") { "spec" }
    watch("spec/rails_helper.rb") { "spec" }

    watch(%r{^app/controllers/api/v2/(.+)\.rb$}) { |m| "spec/requests/api/v2/#{m[1]}_spec.rb" }
    watch(%r{^app/controllers/api/v3/(.+)\.rb$}) { |m| "spec/requests/api/v3/#{m[1]}_spec.rb" }

    watch(%r{^app/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.*)(\.erb|\.haml)$}) { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }

    watch("config/routes.rb") { "spec/routing" }
    watch("app/controllers/application_controller.rb") { "spec/controllers" }

    watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_request_spec.rb" }
    watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_controller_spec.rb" }
  end
end
