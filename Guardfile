directories %w[app spec config]

group :red_green_refactor, halt_on_fail: true do
  rspec_options = {
    cmd: "SKIP_CSS_BUILD=true bin/rspec -f progress",
    cmd_additional_args: "--require rails_helper --no-profile --order defined",
    run_all: {
      cmd: "turbo_tests --quiet --test-options='-f documentation -o /dev/null -f progress",
      cmd_additional_args: "'"
    },
    failed_mode: :focus,
    all_after_pass: false
  }

  guard :rspec, rspec_options do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^config/initializers/(.+)\.rb$}) { |m| "spec/initializers/#{m[1]}_spec.rb" }

    watch("spec/spec_helper.rb") { "spec" }
    watch("spec/rails_helper.rb") { "spec" }

    watch("config/routes.rb") { "spec/routing" }
    watch("app/controllers/application_controller.rb") { "spec/controllers" }

    watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_request_spec.rb" }
    watch(%r{^app/controllers/(.+)_controller\.rb$}) { |m| "spec/requests/#{m[1]}_controller_spec.rb" }

    watch(%r{^app/services/(.+)\.rb$}) { |m| "spec/services/#{m[1]}_spec.rb" }
    watch(%r{^app/models/concerns/(.+)\.rb$}) { |m| "spec/models/concerns/#{m[1]}_spec.rb" }
    watch(%r{^app/components/(.+)rb$}) { |m| "spec/components/#{m[1]}_spec.rb" }
    watch(%r{^app/components/(.+)rb$}) { |m| "spec/components/#{m[1]}_system_spec.rb" }

    watch(%r{^app/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.*)(\.erb|\.haml)$}) { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  end
end
