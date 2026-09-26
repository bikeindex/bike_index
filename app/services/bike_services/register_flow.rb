# frozen_string_literal: true

module BikeServices
  # The register flow's shape. report: :after_details, :last, or nil for a registration
  # with nothing to report
  RegisterFlow = Data.define(:single_page, :page_count, :report) do
    def initialize(single_page: false, page_count: 0, report: nil)
      super
    end

    def single_page? = single_page

    # The e-vehicle acknowledgment pages, which end at the review
    def acknowledgments? = page_count.positive?

    def steps
      details = single_page ? %w[1] : %w[1 2]
      acknowledgments = page_count.times.map { BikeServices::Register.step_for_page_index(it) } +
        (acknowledgments? ? %w[review] : [])
      case report
      when :after_details then details + %w[report] + acknowledgments
      when :last then details + acknowledgments + %w[report]
      else details + acknowledgments
      end
    end

    def count = steps.count

    # 1-based, what the progress bar fills to
    def position(step) = steps.index(step.to_s).to_i + 1

    # What the next and back links go to - nil for the steps nothing comes before or after
    def after(step) = steps[position(step)]

    def before(step)
      index = position(step) - 2
      steps[index] unless index.negative?
    end
  end
end
