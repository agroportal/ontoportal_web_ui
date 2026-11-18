module AdminHelper
  
  ADMIN_URL = "#{LinkedData::Client.settings.rest_url}/admin/"
  ONTOLOGIES_URL = "#{ADMIN_URL}ontologies_report"
  
  def selected_admin_section?(section_title)
    current_section = params[:section] || 'site'
    current_section.eql?(section_title)
  end


  def new_ontologies_created_title
    content_tag(:div,
                t('admin.new_ontologies_created_title', count: @new_ontologies_count.join(', ')),
                style: 'width: 400px; max-height: 300px')
  end

  def visits_evolution
    return 0 if @users_visits[:visits].empty?

    @users_visits[:visits].last - @users_visits[:visits][-2]
  end

  def action_button(name, link, method: :post, class_style: 'btn btn-link')
    button_to name, link, method: method, class: class_style,
                form: {data: { turbo: true, turbo_confirm: t('admin.turbo_confirm', name: name), turbo_frame: '_top'}}

  end


  def get_ontologies_report
    response = {ontologies: Hash.new, report_date_generated: "NEVER GENERATED", errors: '', success: ''}
    start = Time.now

    begin
      ontologies_data = LinkedData::Client::HTTP.get(ONTOLOGIES_URL, {}, raw: true)
      ontologies_data_parsed = JSON.parse(ontologies_data, :symbolize_names => true)

      if ontologies_data_parsed[:errors]
        _process_errors(ontologies_data_parsed[:errors], response, true)
      else
        response.merge!(ontologies_data_parsed)
        response[:success] = t('admin.report_successfully_regenerated', report_date_generated: ontologies_data_parsed[:report_date_generated])
        LOG.add :debug, t('admin.ontologies_report_retrieved', ontologies: response[:ontologies].length, time: Time.now - start)
      end
    rescue Exception => e
      response[:errors] = t('admin.problem_retrieving_ontologies', message: e.message)
    end
    response
  end

end
