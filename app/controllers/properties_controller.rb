class PropertiesController < ApplicationController
  include TurboHelper, SearchContent, TermsReuses, PropertiesHelper

  def index
    acronym = params[:ontology]
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    @submission = @ontology.explore.latest_submission(include:'uriRegexPattern,preferredNamespaceUri,naturalLanguage')

    ontology_not_found(acronym) if @ontology.nil?

    if params[:search].blank?
      index_tree('properties_sorted_list_view-page-1')
    else
      query, page, page_size = helpers.search_content_params

      results, _, next_page, total_count = search_ontologies_content(query: query,
                                                                     page: page,
                                                                     page_size: page_size,
                                                                     filter_by_ontologies: [acronym],
                                                                     filter_by_types: %w[AnnotationProperty ObjectProperty DatatypeProperty])


      render inline: helpers.render_search_paginated_list(container_id: 'properties_sorted_list',
                                                          next_page_url: "/ontologies/#{@ontology.acronym}/properties",
                                                          child_url: "/ontologies/#{@ontology.acronym}/properties/show",
                                                          child_turbo_frame: 'property_show',
                                                          child_param: :propertyid,
                                                          results:  results, next_page:  next_page, total_count: total_count)
    end
  end


  def show
    @acronym = params[:ontology]
    @property = get_property(params[:id],  @acronym, include: 'all')

    redirect_to(ontology_path(id: params[:ontology], p: 'properties', propertyid: params[:id], lang: request_lang)) and return unless turbo_frame_request?

    render partial: 'show'
  end


  def show_children
    acronym = params[:ontology]
    id = params[:propertyid]
    @property = get_property(id, acronym)
    @property.children = property_children(id, acronym)

    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    @submission = @ontology.explore.latest_submission({include: 'uriRegexPattern,preferredNamespaceUri,naturalLanguage'})


    render turbo_stream: [
      replace(helpers.child_id(@property) + '_open_link') { TreeLinkComponent.tree_close_icon },
      replace(helpers.child_id(@property) + '_childs') do
        helpers.property_tree_component(@property, @property, acronym, request_lang, sub_tree: true, submission: @submission)
      end
    ]
  end

  private


  def property_tree(id, acronym = params[:acronym], lang = request_lang)
    LinkedData::Client::HTTP.get("/ontologies/#{acronym}/properties/#{helpers.encode_param(id)}/tree", { lang: lang })
  end

  def property_roots(acronym = params[:acronym], lang = request_lang)
    LinkedData::Client::HTTP.get("/ontologies/#{acronym}/properties/roots", { lang: lang })
  end

  def property_children(id, acronym = params[:acronym], lang = request_lang)
    LinkedData::Client::HTTP.get("/ontologies/#{acronym}/properties/#{helpers.encode_param(id)}/children", { lang: lang })
  end


  private

  def index_tree(container_id)
    if !params[:propertyid].blank?
      @root = OpenStruct.new({ children: property_tree(params[:propertyid], params[:ontology]) })
      not_found(@root.children.errors.join) if @root.children.respond_to?(:errors)

      @property = get_property(params[:propertyid], params[:ontology])
    else
      @root = OpenStruct.new({ children: property_roots(params[:ontology]) })
      not_found(@root.children.errors.join) if @root.children.respond_to?(:errors)

      @property ||= @root.children.first
    end
    render inline: helpers.property_tree_component(@root, @property,
                                                   @ontology.acronym, request_lang,
                                                   id: container_id, auto_click: true)
  end

end
