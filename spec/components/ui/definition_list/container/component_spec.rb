# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DefinitionList::Container::Component, type: :component do
  it "accepts the valid terms and raises for anything else" do
    %i[left_align right_align below].each do |term|
      expect { render_inline(described_class.new(term:)) }.not_to raise_error
    end
    expect { described_class.new(term: :center) }.to raise_error(ArgumentError, /term must be one of/)
  end
end
