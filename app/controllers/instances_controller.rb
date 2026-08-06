class InstancesController < ApplicationController
  include InstancesHelper, SearchContent, TermsReuses

  def index
    if params[:type].blank?
      concept_type =  'NamedIndividual'
    else
      is_concept_instance = true
      concept_type = params[:type]
    end

    get_ontology(params)
    @submission  = @ontology.explore.latest_submission(include:'uriRegexPattern,preferredNamespaceUri')
    query, page, page_size = helpers.search_content_params

    results, _, next_page, total_count = search_ontologies_content(query: query,
                                                                   page: page,
                                                                   page_size: page_size,
                                                                   filter_by_ontologies: [@ontology.acronym],
                                                                   filter_by_types: Array(concept_type))

    view = helpers.render_search_paginated_list(container_id: (is_concept_instance ? 'concept_' : '') + 'instances_sorted_list',
                                                next_page_url: "/ontologies/#{@ontology.acronym}/instances?type=#{helpers.escape(params[:type])}",
                                                child_url: "/ontologies/#{@ontology.acronym}/instances/show?modal=#{is_concept_instance.to_s}",
                                                child_turbo_frame: 'instance_show',
                                                child_param: :instanceid,
                                                show_count: is_concept_instance,
                                                auto_click: false,
                                                results:  results, next_page:  next_page, total_count: total_count)

    if is_concept_instance && page.eql?(1)
      render turbo_stream: view
    else
      render inline:  view
    end
  end

  def show
    get_ontology(params)
    # `lang: 'all'` because this view lists a resource triple by triple: the API
    # otherwise keeps only literals in the request language, hiding the ones a
    # reified node usually carries its text in.
    @instance = get_instance_details_json(params[:ontology], params[:id] || params[:instanceid],
                                          { include: 'all', lang: 'all' })

    redirect_to(ontology_path(id: params[:ontology], p: 'instances', instanceid: params[:id] || params[:instanceid], lang: request_lang)) and return unless turbo_frame_request?

    render partial: 'show'
  end

  private

  def get_ontology(params)
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology] || params[:acronym] || params[:ontology_id]).first
    ontology_not_found(params[:ontology]) if @ontology.nil?
  end
end
