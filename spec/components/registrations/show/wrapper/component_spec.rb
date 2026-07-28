# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::Wrapper::Component, type: :component do
  # The whole show tree renders inside this component's cache block
  it_behaves_like "cache_version_checkpoint", %w[registrations/show]
end
