# frozen_string_literal: true

require "rails_helper"

# A modal trigger names its dialog with commandfor, which is what the browser reads and what
# ui--modal falls back to. data-open-modal used to do that job; UI::Button forwards an unknown
# kwarg verbatim, so a trigger left on the old name still renders and still passes a spec
# asserting the attribute - it just opens nothing.
RSpec.describe "modal triggers" do
  it "names its dialog with commandfor, never the retired data-open-modal" do
    retired = /data-open-modal|open_modal:/
    offenders = Dir[Rails.root.join("app/**/*.{erb,haml,rb}")].select do |path|
      File.read(path).match?(retired)
    end

    expect(offenders).to eq([])
  end
end
