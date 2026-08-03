class AdminController < ApplicationController
  include TurboHelper, HomeHelper, SparqlHelper, AdminHelper
  layout :determine_layout
  before_action :authorize_admin
  before_action :cache_setup

    USERS_URL = "#{LinkedData::Client.settings.rest_url}/users"
  ONTOLOGY_URL = lambda { |acronym| "#{ADMIN_URL}ontologies/#{acronym}" }
  PARSE_LOG_URL = lambda { |acronym| "#{ONTOLOGY_URL.call(acronym)}/log" }

  def sparql_endpoint
    graph = params["named-graph-uri"]
    apikey = params["apikey"]
    user_name = params["username"]

    unless user_name.blank?
      user = LinkedData::Client::Models::User.find(user_name, {include: 'all', apikey: apikey})
      render(inline: 'Query not permitted') && return if user.nil?
    end

    render(inline: 'Query not permitted') && return if graph.blank? && !user&.admin?

    unless graph.blank?
      acronym = graph.split('/')[-3]
      @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym, {apikey: apikey}).first
      render(inline: t('admin.query_not_permitted')) && return  if @ontology.nil? || @ontology.errors
    end

    response = helpers.ontology_sparql_query(params[:query], graph)

    render inline:  response
  end

  def index
  end

  def metadata_administration
    render 'metadata_administration'
  end

  def update_check_enabled
    enabled = LinkedData::Client::HTTP.get("#{ADMIN_URL}update_check_enabled", {}, raw: false)

    if enabled
      response = {update_info: Hash.new, errors: nil, success: '', notices: ''}
      json = LinkedData::Client::HTTP.get("#{ADMIN_URL}update_info", params, raw: true)

      begin
        update_info = JSON.parse(json)

        if update_info["error"]
          response[:errors] = update_info["error"]
        else
          response[:update_info] = update_info
          response[:notices] = update_info["notes"] if update_info["notes"]
          response[:success] = t('admin.update_info_successfully')
        end
      rescue Exception => e
        response[:errors] = t('admin.error_update_info', message: e.message)
      end

      if response[:errors]
        render_turbo_stream alert(id: 'update_check_frame', type: 'danger') { response[:errors] }
      else
        output = []

        output << response[:update_info]["notes"]  if response[:update_info]["update_available"]

        output << t('admin.current_version', version: response[:update_info]['current_version'])
        output << t('admin.appliance_id', id: response[:update_info]['appliance_id'])


        render_turbo_stream *output.map{|message|   alert(id: 'update_check_frame', type: 'info') {message} }


      end
    else
      render_turbo_stream alert(id: 'update_check_frame', type: 'info') { 'not enabled' }
    end
  end


  def parse_log
    @acronym = params["acronym"]
    @parse_log = LinkedData::Client::HTTP.get(PARSE_LOG_URL.call(params["acronym"]), {}, raw: false)
    ontologies_report = helpers.get_ontologies_report
    ontology = ontologies_report[:ontologies][params["acronym"].to_sym]
    @log_file_path = ''

    if ontology
      full_log_file_path = ontology[:logFilePath]
      @log_file_path = /#{params["acronym"]}\/\d+\/[-a-zA-Z0-9_]+\.log$/.match(full_log_file_path)
    else
      @parse_log = t('admin.no_record_exists', acronym: params["acronym"])
      @log_file_path = "None"
    end
    render action: "parse_log"
  end

  def clearcache
    response = {errors: nil, success: ''}

    if @cache.respond_to?(:flush_all)
      begin
        @cache.flush_all
        FederatedPortal.sync!({})
        response[:success] = t('admin.cache_flush_success')
      rescue Exception => e
        response[:errors] = t('admin.cache_flush_error', class: e.class, message: e.message)
      end
    else
      response[:errors] = t('admin.no_flush_command')
    end

    respond_to do |format|
      format.turbo_stream do
        if response[:errors]
          render_turbo_stream alert(type: 'danger') { response[:errors].to_s }
        else
          render_turbo_stream alert(type: 'success') { response[:success] }
        end
      end
    end

  end

  def resetcache
    response = {errors: nil, success: ''}

    if @cache.respond_to?(:reset)
      begin
        @cache.reset
        response[:success] = t('admin.cache_reset_success')
      rescue Exception => e
        response[:errors] = t('admin.cache_reset_error', message: e.message)
      end
    else
      response[:errors] =  t('admin.no_reset_command')
    end

    respond_to do |format|
      format.turbo_stream do
        if response[:errors]
          render_turbo_stream alert(type: 'danger') { response[:errors].to_s }
        else
          render_turbo_stream alert(type: 'success') { response[:success] }
        end
      end
    end
  end

  def clear_goo_cache
    response = {errors: nil, success: ''}

    begin
      response_raw = LinkedData::Client::HTTP.post("#{ADMIN_URL}clear_goo_cache", params, raw: true)
      response[:success] = t('admin.clear_goo_cache_success')
    rescue Exception => e
      response[:errors] = t('admin.clear_goo_cache_error', class: e.class, message: e.message)
    end

    respond_to do |format|
      format.turbo_stream do
        if response[:errors]
          render_turbo_stream alert(type: 'danger') { response[:errors].to_s }
        else
          render_turbo_stream alert(type: 'success') { response[:success] }
        end
      end
    end

  end

  def clear_http_cache
    response = {errors: nil, success: ''}

    begin
      response_raw = LinkedData::Client::HTTP.post("#{ADMIN_URL}clear_http_cache", params, raw: true)
      response[:success] = t('admin.clear_http_cache_success')
    rescue Exception => e
      response[:errors] = t('admin.clear_http_cache_error', class: e.class, message: e.message)
    end

    respond_to do |format|
      format.turbo_stream do
        if response[:errors]
          render_turbo_stream alert(type: 'danger') { response[:errors].to_s }
        else
          render_turbo_stream alert(type: 'success') { response[:success] }
        end
      end
    end
  end

  def ontologies_report
    response = helpers.get_ontologies_report
    render :json => response
  end

  def refresh_ontologies_report
    response = {errors: '', success: ''}

    begin
      response_raw = LinkedData::Client::HTTP.post(ONTOLOGIES_URL, params, raw: true)
      response_json = JSON.parse(response_raw, :symbolize_names => true)

      if response_json[:errors]
        _process_errors(response_json[:errors], response, true)
      else
        response = response_json

        if params["ontologies"].nil? || params["ontologies"].empty?
          response[:success] = t('admin.refresh_report_without_ontologies')
        else
          ontologies = params["ontologies"].split(",").map {|o| o.strip}
          response[:success] = t('admin.refresh_report_with_ontologies', ontologies: ontologies.join(", "))
        end
      end
    rescue Exception => e
      response[:errors] = t('admin.problem_refreshing_report', class: e.class, message: e.message)
      # puts "#{e.class}: #{e.message}\n#{e.backtrace.join("\n\t")}"
    end
    render :json => response
  end


  def process_ontologies
    _process_ontologies('enqued for processing', 'processing', :_process_ontology)
  end

  def delete_ontologies
    _process_ontologies('and all its artifacts deleted', 'deleting', :_delete_ontology)
  end

  def delete_submission
    response = { errors: '', success: '' }
    submission_id = params["id"]
    begin
      ont = params["acronym"]
      ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ont).first

      if ontology
        submission = ontology.explore.submissions({ display: 'submissionId' }, submission_id)

        if submission
          error_response = submission.delete
          if response_error?(error_response)
            errors = response_errors(error_response)
            _process_errors(errors, response, true)
          else
            response[:success] << t('admin.submission_deleted_successfully', id: params["id"], ont: ont)
          end
        else
          response[:errors] << t('admin.submission_not_found', id: params["id"], ont: ont)
        end
      else
        response[:errors] << t('admin.ontology_not_found', ont: ont)
      end
    rescue Exception => e
      response[:errors] << t('admin.problem_deleting_submission', id: params["id"], ont: ont, class: e.class, message: e.message )
    end

    if params[:turbo_stream]
      if response[:errors].empty?
        render_turbo_stream( alert_success { response[:success] }, remove('submission_' + submission_id.to_s))

      else
        render_turbo_stream alert_error { response[:errors] }
      end
    else
      render :json => response
    end

  end


  private

  def cache_setup
    @cache = Rails.cache.instance_variable_get("@data")
  end

  def _process_errors(errors, response, remove_trailing_comma=true)
    if errors.is_a?(Hash)
      errors.each do |_, v|
        if v.kind_of?(Array)
          response[:errors] << v.join(", ")
          response[:errors] << ", "
        else
          response[:errors] << "#{v}, "
        end
      end
    elsif errors.kind_of?(Array)
      errors.each {|err| response[:errors] << "#{err}, "}
    end
    response[:errors] = response[:errors][0...-2] if remove_trailing_comma
  end

  def _delete_ontology(ontology, params)
    error_response = ontology.delete
    error_response
  end

  def _process_ontology(ontology, params)
    LinkedData::Client::HTTP.put(ONTOLOGY_URL.call(ontology.acronym), params)
  end

  def _process_ontologies(success_keyword, error_keyword, process_proc)
    response = {errors: '', success: ''}

    if params["ontologies"].nil? || params["ontologies"].empty?
      response[:errors] = t('admin.no_ontologies_parameter_passed')
    else
      ontologies = params["ontologies"].split(",").map {|o| o.strip}

      ontologies.each do |ont|
        begin
          ontology = LinkedData::Client::Models::Ontology.find_by_acronym(ont).first

          if ontology
            error_response = self.send(process_proc, ontology, params)
            if response_error?(error_response)
              errors = response_errors(error_response) # see application_controller::response_errors
              _process_errors(errors, response, false)
            else
              response[:success] << t('admin.ontology_process_success', ont: ont, success_keyword: success_keyword)
            end
          else
            response[:errors] << t('admin.ontology_not_found_system', ont: ont)
          end
        rescue Exception => e
          response[:errors] << t('admin.ontology_process_error', error_keyword: error_keyword, ont: ont, class: e.class, message: e.message)
        end
      end
      response[:success] = response[:success][0...-2] unless response[:success].empty?
      response[:errors] = response[:errors][0...-2] unless response[:errors].empty?
    end
    render :json => response
  end
end
