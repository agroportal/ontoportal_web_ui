module StatisticsHelper

  def ontologies_by_year_month
    data = LinkedData::Client::Analytics.all.to_h
    data.delete(:links)
    data.delete(:context)
    year_month_count = {}
    year_month_visits = {}
    acronyms = []
    data.each do |acronym, ont|
      ont.each do |year, months|
        next if year.eql?(:links) || year.eql?(:context)
        months.each do |month, count|
          next if month.eql?(:links) || month.eql?(:context)
          year_month_count[[year.to_s.to_i, month.to_s.to_i]] ||= []
          year_month_visits[[year.to_s.to_i, month.to_s.to_i]] = count + (year_month_visits[[year.to_s.to_i, month.to_s.to_i]] || 0)

          if !count.zero? && !acronyms.include?(acronym)
            year_month_count[[year.to_s.to_i, month.to_s.to_i]] << acronym
            acronyms << acronym
          end
        end
      end
    end
    year_month_visits = year_month_visits.sort_by { |(year, month), _| [year, month] }.to_h
    [year_month_count, year_month_visits]
  end

  def string_year_month(year, month)
    DateTime.parse("#{year}/#{month}").strftime("%b %Y")
  end
  def group_by_year_month(data, fallback: nil)
    grouped = data.group_by do |x|
      created = x.respond_to?(:created) ? x.created : nil
      if created.nil? || created.to_s.strip.empty?
        fallback
      else
        [Date.parse(created).year, Date.parse(created).month]
      end
    end
    grouped.delete(nil)
    grouped.sort_by { |(year, month), _| [year, month] }.to_h
  end

  def merge_time_evolution_data(data)
    min_year = data.map { |x| x.keys.first&.first }.compact.min
    old = data.size.times.map { |x|  0 }

    visits_data = { visits: data.size.times.map { |x|  [] }, labels: [] }

    (min_year..Date.today.year).each do |year|
      (1..12).each do |month|
        data.each_with_index do |x , i|
          old[i] += x[[year, month]]&.size || 0
        end

        next if old.sum.zero?

        data.each_index do |i|
          visits_data[:visits][i] << old[i]
        end

        visits_data[:labels] << string_year_month(year, month)
      end
    end
    visits_data
  end

end
