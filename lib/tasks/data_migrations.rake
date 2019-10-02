namespace :data do
end

def print_status(curr, total_count)
  digits = total_count.to_s.length
  count = [curr.to_s.rjust(digits, " "), total_count].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(5, " ")
  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end
