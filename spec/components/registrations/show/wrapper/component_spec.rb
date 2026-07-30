# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::Wrapper::Component, type: :component do
  # The whole show tree renders inside this component's cache block
  it_behaves_like "cached_markup_digest",
    "app/components/registrations/show/consumer/component.html.erb",
    "app/components/registrations/show/org_top_actions/wrapper/component_preview.rb"
end
