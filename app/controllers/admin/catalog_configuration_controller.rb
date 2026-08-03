class Admin::CatalogConfigurationController < ApplicationController
  include OntoportalInstances

  before_action :authorize_admin
  before_action :load_catalog_metadata, only: [:show]
  before_action :load_catalog_data, only: [:show]

  CATALOG_PATH = "#{LinkedData::Client.settings.rest_url}/".freeze
  CATALOG_METADATA_URL = "#{LinkedData::Client.settings.rest_url}/catalog_metadata".freeze

  def show
    @catalog_groups = attributes_groups
    @catalog_metadata ||= session[:catalog_metadata] || load_catalog_metadata
    @catalog_data ||= session[:catalog_data] || load_catalog_data
  end

  def update
    config = sanitize_config_params
    response = update_remote_config(config)
    if response.status == 200
      flash.now[:notice] = t('admin.catalog_configuration.configuration_updated_successfully')
      # Invalidate the federated portals cache on any federation submission, not
      # only when portals remain: emptying the list has to take effect too.
      invalidate_federated_portals_cache if federated_portals_update?
    else
      flash.now[:alert] = t('admin.catalog_configuration.configuration_update_error', error: response.body)
    end

    if @rejected_federated_portals.present?
      flash.now[:warning] = t('admin.catalog_configuration.federation_invalid_apikeys',
                              portals: @rejected_federated_portals.join(', '))
    end

    @catalog_data = load_catalog_data
    session[:catalog_data] = @catalog_data
    @catalog_metadata = session[:catalog_metadata] || load_catalog_metadata
    @catalog_groups = attributes_groups

    respond_to do |format|
      format.turbo_stream do
        if federated_portals_update?
          render turbo_stream: turbo_stream.replace(
            'federated-portals-config',
            partial: 'admin/catalog_configuration/federated_portals'
          )
        else
          render turbo_stream: turbo_stream.replace(
            'catalog-config',
            render_to_string('admin/catalog_configuration/show')
          )
        end
      end
      format.html { redirect_to admin_api_configuration_index_path }
    end
  end

  def edit_nested_form
    # Use cached data from session, fallback to fresh fetch if needed
    @key = params[:key]&.to_sym
    return head :bad_request unless @key

    @catalog_data = session[:catalog_data] || load_catalog_data
    @catalog_metadata = session[:catalog_metadata] || load_catalog_metadata

    @value_attrs = @catalog_data&.dig(@key) || []

    # Merge federated_portals from ontoportal.org with existing ones
    if @key == :federated_portals
      portals_from_source = fetch_federated_portals_from_source
      @value_attrs = merge_federated_portals(@value_attrs, portals_from_source)
      # For federated_portals, explicitly set all field names
      @field_names = %w[name ui api color apikey]

      domain = current_portal_domain
      @federation_allowed = federation_allowed?
      # Never let a portal federate with itself.
      @value_attrs = reject_current_portal(@value_attrs, domain)
    else
      @field_names = extract_field_names_for_key(@key)
    end

    render partial: 'edit_nested_form_modal', layout: false
  end

  # Live check used by the federated portals form to give immediate feedback
  # before saving: is this apikey a valid, working federation key?
  def validate_apikey
    apikey = params[:apikey].to_s
    api = params[:api].to_s

    render json: {
      uuid: valid_uuid?(apikey),
      valid: valid_federation_apikey?(api, apikey)
    }
  end

  private

  # The federated portals form is submitted on its own, from the site
  # administration section, and so refreshes that section instead of the
  # site description form.
  def federated_portals_update?
    params[:config]&.key?('federated_portals')
  end

  # A portal may only activate federation if it is itself registered as a
  # federated portal on ontoportal.org (matched by the request host).
  # Development runs on a host that is never registered there, which would leave
  # the form permanently locked, so the gate does not apply.
  def federation_allowed?
    Rails.env.development? || current_portal_federated_on_source?
  end

  def attributes_groups
    {
      general: %w[acronym title identifier versionInfo status],
      licensing: %w[accessRights rightsHolder license morePermissions],
      description: %w[
        description comment keyword alternative hiddenLabel 
        bibliographicCitation isReferencedBy
      ],
      dates: %w[created modified],
      agents: %w[
        creator contributor publisher contactPoint curatedBy 
        translator endorsedBy fundedBy funding
      ],
      community: %w[
        audience publishingPrinciples repository bugDatabase 
        mailingList toDoList award
      ],
      usage: %w[knownUsage coverage example themeTaxonomy],
      methodology_and_provenance: %w[accrualMethod accrualPeriodicity accrualPolicy],
      media: %w[associatedMedia depiction logo],
      other: %w[color relation sampleQueries]
    }.freeze
  end

  # Attributes that are part of the catalog configuration but are not edited
  # from the site description form: federated portals live in the site
  # administration section.
  def standalone_attributes
    %w[federated_portals].freeze
  end

  def list_included_attributes
    (attributes_groups.values.flatten + standalone_attributes).freeze
  end

  def agents_list
    %w[
      rightsHolder contactPoint creator contributor curatedBy 
      translator publisher endorsedBy
    ].freeze
  end

  def load_catalog_data
    return @catalog_data if @catalog_data

    params = build_catalog_params(exclude_agents: true)
    @catalog_data = LinkedData::Client::HTTP.get(CATALOG_PATH, params).to_hash
    agent_params = build_catalog_params(agents_only: true)
    catalog_agents = LinkedData::Client::HTTP.get(CATALOG_PATH, agent_params).to_hash
    @catalog_data.merge!(catalog_agents.to_hash)
    @catalog_data = sanitize_catalog_data(@catalog_data)
    session[:catalog_data] = @catalog_data
    @catalog_data
  rescue StandardError => e
    handle_catalog_error(e, 'catalog data')
    @catalog_data = {}
    session[:catalog_data] = @catalog_data
    @catalog_data
  end

  def load_catalog_metadata
    return @catalog_metadata if @catalog_metadata

    catalog_metadata_list = LinkedData::Client::HTTP.get(CATALOG_METADATA_URL, {})
    filtered_metadata = catalog_metadata_list.select do |metadata| 
      list_included_attributes.include?(metadata.attribute) 
    end
    
    @catalog_metadata = filtered_metadata.index_by(&:attribute)
    session[:catalog_metadata] = @catalog_metadata
    @catalog_metadata
  rescue StandardError => e
    @catalog_metadata = {}
    session[:catalog_metadata] = @catalog_metadata
    @catalog_metadata
  end

  def build_catalog_params(exclude_agents: false, agents_only: false)
    included_attrs = if agents_only
                      agents_list
                    elsif exclude_agents
                      list_included_attributes - agents_list
                    else
                      list_included_attributes
                    end

    {
      include: included_attrs.join(','),
      display_links: false,
      display_context: false,
      _ts: Time.current.to_i
    }
  end

  def update_remote_config(config)
    response = LinkedData::Client::HTTP.patch(CATALOG_PATH, config)
  rescue StandardError => e
    Rails.logger.error("Config update failed: #{e.message}")
    OpenStruct.new(status: 500, body: e.message)
  end

  def sanitize_catalog_data(catalog_data)
    catalog_data_sanitized = catalog_data
    # sanitize themeTaxonomy to let only the acronyms of the ontologies
    catalog_data_sanitized[:themeTaxonomy] = catalog_data_sanitized[:themeTaxonomy].select { |url| url.start_with?(rest_url) }.map { |url| url.split('/').last }
    return catalog_data_sanitized
  end

  def sanitize_config_params
    config = params.require(:config).permit!.to_h

    list_included_attributes.each do |key|
      # Special handling for federated_portals
      if key == 'federated_portals'
        config[key] = sanitize_federated_portals(config[key.to_s])
      else
        config[key] = sanitize_attribute_value(config[key.to_s])
      end
    end

    config['rightsHolder'] = config['rightsHolder']&.first&.presence || '' if config['rightsHolder']

    # rebuild themeTaxonomy as URIs
    config['themeTaxonomy'] = config['themeTaxonomy'].map { |value| "#{rest_url.chomp('/')}/#{value}" } if config['themeTaxonomy']
    config['themeTaxonomy'] << "http://vocabularies.unesco.org/thesaurus" if config['themeTaxonomy']
    config.compact
  end

  def sanitize_attribute_value(raw_value)
    return nil if raw_value.nil?

    case raw_value
    when Hash
      raw_value.values.filter_map { |v| v.is_a?(Hash) ? v['id'] : nil }
    when Array
      raw_value.reject(&:blank?)
    else
      raw_value
    end
  end

  def sanitize_federated_portals(raw_value)
    return nil if raw_value.nil?

    portals_data = case raw_value
                   when Hash
                     # raw_value is a hash with numeric keys and portal data as values
                     raw_value.values
                   when Array
                     # raw_value is already an array of portal objects
                     raw_value
                   else
                     []
                   end

    @rejected_federated_portals ||= []

    portals = portals_data.filter_map do |portal_data|
      next unless portal_data.is_a?(Hash)
      # The apikey is required: skip portals without one so they are not
      # added to the catalog.
      next if portal_data['apikey'].blank?

      portal = {}
      portal[:name] = portal_data['name'] if portal_data['name'].present?
      portal[:ui] = portal_data['ui'] if portal_data['ui'].present?
      portal[:api] = portal_data['api'] if portal_data['api'].present?
      portal[:color] = portal_data['color'] if portal_data['color'].present?
      portal[:apikey] = portal_data['apikey']

      # Only keep portals whose apikey is a valid, working federation key.
      unless valid_federation_apikey?(portal[:api], portal[:apikey])
        @rejected_federated_portals << (portal[:name].presence || portal[:ui].presence || portal[:api].presence)
        next
      end

      portal
    end

    portals.presence
  end

  UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def valid_uuid?(value)
    value.to_s.match?(UUID_REGEX)
  end

  # A federation apikey must be a valid UUID and must be accepted by the target
  # portal. We probe its API and only reject the key when the portal answers
  # with 401 Unauthorized. Any other outcome (including a network error we
  # cannot draw a conclusion from) leaves the key in place.
  def valid_federation_apikey?(api, apikey)
    return false unless valid_uuid?(apikey)
    return true if api.blank?

    uri = URI.parse("#{api.to_s.chomp('/')}/agents")
    uri.query = URI.encode_www_form(
      page: 1, pagesize: 1, include: 'test',
      display_links: false, display_context: false, apikey: apikey
    )

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                   open_timeout: 5, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(uri.request_uri))
    end

    response.code.to_i != 401
  rescue StandardError => e
    Rails.logger.warn("Could not verify federation apikey for #{api}: #{e.message}")
    true
  end

  def extract_field_names_for_key(key)
    metadata = @catalog_metadata[key.to_s]
    return [] unless metadata&.enforcedValues

    metadata.enforcedValues.flat_map do |field|
      field.to_h.keys - [:links, :context]
    end
  end

  # The apikey is deliberately left out: it is what the administrator has to fill in
  # to actually federate with a portal.
  def fetch_federated_portals_from_source
    federated_ontoportal_instances.map do |portal|
      OpenStruct.new(
        name: portal[:name],
        ui: portal[:ui],
        api: portal[:api],
        color: portal[:color]
      )
    end
  rescue StandardError => e
    Rails.logger.error("Error fetching federated portals: #{e.message}")
    []
  end

  # The domain that identifies the current portal, taken from the incoming
  # request host rather than a configurable setting the admin controls.
  def current_portal_domain
    portal_domain(request.host)
  end

  # Remove the current portal from the list so it is not offered to federate
  # with itself.
  def reject_current_portal(portals, domain)
    return portals if domain.blank?

    portals.reject do |portal|
      ui = portal.respond_to?(:ui) ? portal.ui : portal['ui']
      api = portal.respond_to?(:api) ? portal.api : portal['api']
      [portal_domain(ui), portal_domain(api)].compact.include?(domain)
    end
  end

  def merge_federated_portals(existing_portals, source_portals)
    # Create a map of existing portals by normalized UI domain
    existing_by_domain = {}
    existing_portals.each do |portal|
      ui = portal.respond_to?(:ui) ? portal.ui : portal['ui']
      next if ui.blank?

      domain = portal_domain(ui)
      existing_by_domain[domain] = portal
    end

    # Add portals from source, avoiding duplicates by domain
    source_portals.each do |portal|
      next if portal.ui.blank?

      domain = portal_domain(portal.ui)
      existing_by_domain[domain] ||= portal
    end

    # Return merged list
    existing_by_domain.values
  end

  def invalidate_federated_portals_cache
    Rails.cache.delete('federated_portals')
    Rails.logger.info("Invalidated federated_portals cache")
  end


end