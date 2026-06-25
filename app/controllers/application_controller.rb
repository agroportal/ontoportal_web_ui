require 'uri'
require 'open-uri'
require 'net/http'
require 'net/https'
require 'net/ftp'
require 'json'
require 'cgi'
require 'rexml/document'
require 'rest-client'
require 'ontologies_api_client'

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include InternationalisationHelper, MultiLanguagesHelper

  before_action :set_locale

  def self.t(*args)
    InternationalisationHelper.t(*args)
  end

  # Sets the locale based on the locale cookie or the value returned by detect_locale.
  def set_locale
    I18n.locale = cookies[:locale] || detect_locale
    cookies.permanent[:locale] = I18n.locale if cookies[:locale].nil?
    logger.debug "* Locale set to '#{I18n.locale}'"

    I18n.locale = portal_lang unless portal_language_enabled?(I18n.locale)

    session[:locale] = I18n.locale
  end

  # Returns detedted locale based on the Accept-Language header of the request or the default locale if none is found.
  def detect_locale
    languages = request.headers['Accept-Language']&.split(',')
    supported_languages = I18n.available_locales

    Array(languages).each do |language|
      language_code = language.split(/[-;]/).first.downcase.to_sym
      return language_code if supported_languages.include?(language_code)
    end

    return I18n.default_locale
  end


  helper :all # include all helpers, all the time
  helper_method :bp_config_json, :current_license, :using_captcha?, :assistant_enabled?

  if !Rails.env.development? && !Rails.env.test?
    rescue_from ActiveRecord::RecordNotFound, with: :not_found_record
  end

  # Pull configuration parameters for REST connection.
  REST_URI = $REST_URL
  API_KEY = $API_KEY


  $DATA_CATALOG_VALUES = {"fairsharing.org/" => "FAIRsharing",
                         "aber-owl.net" => "AberOWL",
                         "vest.agrisemantics.org" => "VEST Registry",
                         "bioportal.bioontology.org" => "BioPortal",
                         "ontobee.org" => "Ontobee",
                         "obofoundry.org" => "The OBO Foundry",
                         "ebi.ac.uk/ols" => "EBI Ontology Lookup"}

  RESOLVE_NAMESPACE = {:omv => "http://omv.ontoware.org/2005/05/ontology#", :skos => "http://www.w3.org/2004/02/skos/core#", :owl => "http://www.w3.org/2002/07/owl#",
                       :rdf => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", :rdfs => "http://www.w3.org/2000/01/rdf-schema#", :metadata => "http://data.bioontology.org/metadata/",
                       :metadata_def => "http://data.bioontology.org/metadata/def/", :dc => "http://purl.org/dc/elements/1.1/", :xsd => "http://www.w3.org/2001/XMLSchema#",
                       :oboinowl_gen => "http://www.geneontology.org/formats/oboInOwl#", :obo_purl => "http://purl.obolibrary.org/obo/",
                       :umls => "http://bioportal.bioontology.org/ontologies/umls/", :door => "http://kannel.open.ac.uk/ontology#", :dct => "http://purl.org/dc/terms/",
                       :void => "http://rdfs.org/ns/void#", :foaf => "http://xmlns.com/foaf/0.1/", :vann => "http://purl.org/vocab/vann/", :adms => "http://www.w3.org/ns/adms#",
                       :voaf => "http://purl.org/vocommons/voaf#", :dcat => "http://www.w3.org/ns/dcat#", :mod => "http://www.isibang.ac.in/ns/mod#", :prov => "http://www.w3.org/ns/prov#",
                       :cc => "http://creativecommons.org/ns#", :schema => "http://schema.org/", :doap => "http://usefulinc.com/ns/doap#", :bibo => "http://purl.org/ontology/bibo/",
                       :wdrs => "http://www.w3.org/2007/05/powder-s#", :cito => "http://purl.org/spar/cito/", :pav => "http://purl.org/pav/", :nkos => "http://w3id.org/nkos/nkostype#",
                       :oboInOwl => "http://www.geneontology.org/formats/oboInOwl#", :idot => "http://identifiers.org/idot/", :sd => "http://www.w3.org/ns/sparql-service-description#",
                       :cclicense => "http://creativecommons.org/licenses/"}

  $trial_license_initialized = false


  # See ActionController::RequestForgeryProtection for details
  protect_from_forgery

  before_action :set_global_thread_values, :domain_ontology_set, :clean_empty_strings_from_params_arrays, :init_trial_license


  def invalidate_cache?
    params[:invalidate_cache] && params[:invalidate_cache].to_s.eql?('true')
  end
  def show_image_modal
    url = params[:url]
    render turbo_stream: helpers.prepend('application_modal_content') { helpers.image_tag(url, style:'width: 100%') }
  end

  def set_global_thread_values
    Thread.current[:session] = session
    Thread.current[:request] = request
  end

  def clean_empty_strings_from_params_arrays(params = nil)
    params ||= params()
    params.keys.each do |k|
      clean_empty_strings_from_params_arrays(params[k]) if params[k].is_a?(Hash)
      params[k] = params[k].select {|e| !e.eql?("")} if params[k].is_a?(Array)
    end
  end

  def domain_ontology_set
    @subdomain_filter = { :active => false, :name => "", :acronym => "" }

    if !$ENABLE_SLICES.nil? && $ENABLE_SLICES == true
      host = request.host
      host_parts = host.split(".")
      subdomain = host_parts[0].downcase

      slices = LinkedData::Client::Models::Slice.all
      slices_acronyms = slices.map {|s| s.acronym}

      # Set custom ontologies if we're on a subdomain that has them
      # Else, make sure user ontologies are set appropriately
      if slices_acronyms && slices_acronyms.include?(subdomain)
        slice = slices.select {|s| s.acronym.eql?(subdomain)}.first
        @subdomain_filter[:active] = true
        @subdomain_filter[:name] = slice.name
        @subdomain_filter[:acronym] = slice.acronym
        @subdomain_filter[:ontologies] = slice.ontologies
      end
    end

    Thread.current[:slice] = @subdomain_filter
  end

  def ontology_not_found(ontology_acronym)
    not_found(t('application.ontology_not_found',acronym: ontology_acronym))
  end

  def concept_not_found(concept_id)
    not_found(t('application.concept_not_found',concept: concept_id))
  end

  def not_found(message = '')
    if request.xhr?
      render plain: message || t('application.error_load')
      return
    end

    raise ActiveRecord::RecordNotFound.new(message || t('application.not_found_message'))
  end

  def bp_config_json
    # For config settings, see
    # config/bioportal_config.rb
    # config/initializers/ontologies_api_client.rb
    config = {
        org: $ORG,
        org_url: $ORG_URL,
        site: $SITE,
        org_site: $ORG_SITE,
        ui_url: $UI_URL,
        apikey: LinkedData::Client.settings.apikey,
        userapikey: get_apikey,
        rest_url: LinkedData::Client.settings.rest_url,
        proxy_url: $PROXY_URL,
        biomixer_url: $BIOMIXER_URL,
        annotator_url: $ANNOTATOR_URL,
        ncbo_annotator_url: $NCBO_ANNOTATOR_URL,
        ncbo_apikey: $NCBO_API_KEY,
        interportal_hash: $INTERPORTAL_HASH,
        resolve_namespace: RESOLVE_NAMESPACE
    }
    config[:ncbo_slice] = @subdomain_filter[:acronym] if (@subdomain_filter[:active] && !@subdomain_filter[:acronym].empty?)
    config.to_json
  end

  def rest_url
    helpers.rest_url
  end

  def request_portals
    helpers.request_portals
  end

  def parse_response_body(response)
    return nil if response.nil?

    if response.respond_to?(:errors) && response.errors
      response
    else
      OpenStruct.new(JSON.parse(response.body, symbolize_names: true))
    end
  end

  def response_errors(error_response)
    error_struct = parse_response_body(error_response)

    errors = {error: t('application.try_again')}
    return errors unless error_struct
    return errors unless error_struct.respond_to?(:errors)
    errors = {}
    error_struct.errors.each do |error|
      if error.is_a?(OpenStruct) || error.is_a?(Struct)
        errors.merge!(struct_to_hash(error))
      else
        errors[:error] = error
      end
    end
    errors
  end

  def response_success?(response)
    return true if response.nil?

    if response.respond_to?(:status) && response.status
        response.status.to_i < 400
    else
      !(response.respond_to?(:errors) && response.errors)
    end
  end

  def response_error?(response)
    !response_success?(response)
  end

  def struct_to_hash(struct)
    hash = {}
    struct.members.each do |attr|
      next if [:links, :context].include?(attr)
      if struct[attr].is_a?(Struct) || struct[attr].is_a?(OpenStruct)
        hash[attr] = struct_to_hash(struct[attr])
      else
        hash[attr] = struct[attr]
      end
    end
    hash
  end

  def redirect_to_browse # Redirect to the browse Ontologies page
    redirect_to "/ontologies"
  end

  def redirect_to_user_ontologies # Redirect to the My ontologies page
    redirect_to "/my-ontologies"
  end

  def redirect_to_home # Redirect to Home Page
    redirect_to "/"
  end
  
  # Redirects to home if the application is in read-only mode.  
  def authorize_read_only
    if helpers.read_only_enabled?
      redirect_to_home and return
    end
  end

  # Verifies if user is logged in
  def authorize_and_redirect
    unless session[:user]
      redirect_to_home
    end
  end
  
  def authorize_admin
    redirect_to_home unless current_user_admin?
  end

  def current_user_admin?
    session[:user]&.admin? || current_login_as_admin?
  end

  def current_login_as_admin?
    session[:admin_user]&.admin?
  end

  # True when the smart assistant feature is enabled and fully configured.
  # Sign-in gating is applied separately (layout + AssistantController).
  def assistant_enabled?
    $ASSISTANT_ENABLED &&
      $ASSISTANT_LLM_API_URL.present? &&
      $ASSISTANT_LLM_API_KEY.present? &&
      $ASSISTANT_LLM_MODEL.present?
  end

  def ontology_restricted?(acronym)
    restrict_downloads = $NOT_DOWNLOADABLE
    restrict_downloads.include? acronym
  end

  def check_delete_mapping_permission(mappings)
    # ensure mappings is an Array of mappings (some calls may provide only a single mapping instance)
    mappings = [mappings] if mappings.instance_of? LinkedData::Client::Models::Mapping
    return false if mappings.all? {|m| m.id.to_s.empty?}
    delete_mapping_permission = false
    if session[:user]
      delete_mapping_permission = session[:user].admin?
      mappings.each do |mapping|
        break if delete_mapping_permission
        delete_mapping_permission = mapping.creator == session[:user].id
      end
    end
    delete_mapping_permission
  end

  def using_captcha?
    ENV['USE_RECAPTCHA'].present? && ENV['USE_RECAPTCHA'] == 'true'
  end

  def get_class(params)

    lang = request_lang

    if @ontology.flat?

      ignore_concept_param = params[:conceptid].nil? ||
        params[:conceptid].empty? ||
        params[:conceptid].eql?("root") ||
        params[:conceptid].eql?("bp_fake_root")
      if ignore_concept_param
        # Don't display any classes in the tree
        @concept = LinkedData::Client::Models::Class.new
        @concept.prefLabel = t('application.search_for_class')
        @concept.obsolete = false
        @concept.id = "bp_fake_root"
        @concept.properties = {}
        @concept.children = []
      else
        # Display only the requested class in the tree
        @concept = @ontology.explore.single_class({full: true, lang: lang }, params[:conceptid])
        @concept.children = []
      end
      @root = LinkedData::Client::Models::Class.new
      @root.children = [@concept]

    else

      # not ignoring 'bp_fake_root' here
      include = 'prefLabel,hasChildren,obsolete'
      ignore_concept_param = params[:conceptid].nil? ||
        params[:conceptid].empty? ||
        params[:conceptid].eql?("root")
      if ignore_concept_param
        # get the top level nodes for the root
        # TODO_REV: Support views? Replace old view call: @ontology.top_level_classes(view)
        @roots = @ontology.explore.roots(concept_schemes: params[:concept_schemes]) rescue nil

        if @roots.blank? || response_error?(@roots) || @roots.compact&.empty?
          LOG.add :debug, t('application.missing_roots_for_ontology', acronym: @ontology.acronym)
          classes = @ontology.explore.classes.collection
          @concept = classes.first.explore.self(full: true) if classes&.first
          return
        end

        @root = LinkedData::Client::Models::Class.new(read_only: true)
        @root.children = @roots.sort{|x,y| (x&.prefLabel || "").downcase <=> (y&.prefLabel || "").downcase}

        # get the initial concept to display
        root_child = @root.children&.first
        not_found(t('application.missing_roots')) if root_child.nil?

        @concept = root_child.explore.self(full: true, lang: lang)
        # Some ontologies have "too many children" at their root. These will not process and are handled here.
        if @concept.nil?
          LOG.add :debug, t('application.missing_class', root_child: root_child.links.self)
          not_found(t('application.missing_class', root_child: root_child.links.self))
        end
      else
        # if the id is coming from a param, use that to get concept
        @concept = @ontology.explore.single_class({full: true, lang: lang}, params[:conceptid])
        if @concept.nil? || @concept.errors
          LOG.add :debug, t('application.missing_class_ontology', acronym: @ontology.acronym, concept_id: params[:conceptid])
          not_found(t('application.missing_class_ontology', acronym: @ontology.acronym, concept_id: params[:conceptid]))
        end

        # Create the tree
        rootNode = @concept.explore.tree(include: include, concept_schemes: params[:concept_schemes], lang: lang)
        if rootNode.nil? || rootNode.empty?
          @roots = @ontology.explore.roots(concept_schemes: params[:concept_schemes])
          if @roots.nil? || response_error?(@roots) || @roots.compact&.empty?
            LOG.add :debug, t('application.missing_roots_for_ontology', acronym: @ontology.acronym)
            @concept = @ontology.explore.classes.collection.first.explore.self(full: true)
            return
          end
          if @roots.any? {|c| c.id == @concept.id}
            rootNode = @roots
          else
            rootNode = [@concept]
          end
        end
        @root = LinkedData::Client::Models::Class.new(read_only: true)
        @root.children = rootNode.sort{|x,y| (x.prefLabel || "").downcase <=> (y.prefLabel || "").downcase}
      end
    end

    @concept
  end

  def get_ontology_submission_ready(ontology)
    # Get the latest 'ready' submission
    submission = ontology.explore.latest_submission({:include_status => 'ready'})
    # Fallback to the latest submission, even if it's not ready.
    submission = ontology.explore.latest_submission if submission.nil?
    return submission
  end

  def get_apikey()
    apikey = API_KEY
    if session[:user]
      apikey = session[:user].apikey
    end
    return apikey
  end


  def determine_layout
    if Rails.env.appliance?
      'appliance'
    else
      'ontology'
    end
  end

  def current_license
    @current_license = License.current_license.first
  end

  def init_trial_license
    unless $trial_license_initialized
      unless License.where(encrypted_key: 'trial').exists?
        License.create(encrypted_key: 'trial', created_at: Time.current)
      end
      $trial_license_initialized = true
    end
  end

  # Get the submission metadata from the REST API.
  def submission_metadata
    @metadata ||= helpers.submission_metadata
  end

  def request_lang
    helpers.request_lang
  end

  def json_link(url, optional_params)
    base_url = "#{url}?"
    filtered_params = optional_params.reject { |_, value| value.nil? }
    optional_params_str = filtered_params.map { |param, value| "#{param}=#{value}" }.join("&")
    return base_url + optional_params_str + "&apikey=#{$API_KEY}"
  end

  def set_federated_portals
    RequestStore.store[:federated_portals] =  params[:portals]&.split(',')
  end

  private
  def not_found_record(exception)
    @error_message = exception.message

    render 'errors/not_found', status: 404
  end
end
