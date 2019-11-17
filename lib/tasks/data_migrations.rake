include ActionView::Helpers::NumberHelper

def print_progress(curr, total_count)
  total = number_with_delimiter(total_count)
  digits = total.to_s.length

  count = [number_with_delimiter(curr).to_s.rjust(digits, " "), total].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(7, " ")

  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end

namespace :data do
end

