# frozen_string_literal: true

module BikeServices
  # The register flow's shape - every step it reaches, in order, and whether step 1's page
  # asks for step 2's details too. BikeServices::Register.flow builds it once a request
  RegisterFlow = Data.define(:steps, :single_page) do
    def initialize(steps:, single_page: false)
      super
    end

    def single_page? = single_page

    # The e-vehicle acknowledgment pages, which end at the review
    def acknowledgments? = steps.include?("review")

    def count = steps.count

    # 1-based, what the progress bar fills to
    def position(step) = steps.index(step.to_s).to_i + 1

    # What the next and back links go to - nil for the steps nothing comes before or after
    def after(step) = steps[position(step)]

    def before(step)
      steps[position(step) - 2] if position(step) > 1
    end
  end
end
