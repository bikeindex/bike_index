# frozen_string_literal: true

require "rails_helper"

# Stimulus controllers load via importmap (pin_all_from "app/javascript/controllers"). A relative
# specifier like './sortable_controller' resolves to a non-digested URL that 404s once assets are
# precompiled, so the importing controller silently never connects in production (while dev/test,
# served non-digested, work fine). Import sibling modules by pinned name: 'controllers/sortable_controller'.
RSpec.describe "app/javascript/controllers importmap compatibility" do
  it "imports modules by pinned name, never a relative path" do
    relative_specifier = %r{\bfrom\s+['"]\.{1,2}/}
    offenders = Dir[Rails.root.join("app/javascript/controllers/**/*.js")].select do |path|
      File.read(path).match?(relative_specifier)
    end

    expect(offenders).to eq([])
  end
end
