module AdminHelper
  def admin_display_date(time)
    if time.today?
      "Today at #{time.strftime('%-I:%M%p').downcase}"
    elsif Date.yesterday.beginning_of_day <= time
      "Yesterday at #{time.strftime('%-I:%M%p').downcase}"
    else
      "#{time.strftime('%-m/%-d/%Y at')} #{time.strftime('%-I%p').downcase}"
    end
  end
end
