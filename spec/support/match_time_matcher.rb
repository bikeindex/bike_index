# for this application, estimated relevant precision
DEFAULT_PRECISION = 0.0001

RSpec::Matchers.define :match_time do |expected, within = DEFAULT_PRECISION|
  match do |subject|
    @within = if within.is_a?(ActiveSupport::Duration)
      within.to_f # Convert duration to number
    elsif within.blank?
      0.001
    else
      within
    end

    # Assign to ivar so it's accessible
    @expected = expected.in_time_zone(TimeParser::DEFAULT_TIME_ZONE)
    lower_bound = (@expected - within).to_f
    upper_bound = (@expected + within).to_f

    # Coerce subject to float
    @subject = TimeParser.parse(subject)

    @subject.to_f.between?(lower_bound, upper_bound)
  end

  def time_display(time)
    time.in_time_zone(TimeParser::DEFAULT_TIME_ZONE).iso8601(8)
  end

  failure_message do |_expected|
    "expected #{time_display(@subject)} to be within: #{@within} of\n         " \
    "#{time_display(@expected)}"
  end

  failure_message_when_negated do |_expected|
    "expected #{time_display(@subject)} not to be within: #{@within} of\n         " \
    "#{time_display(@expected)}"
  end
end
