class CollectionsController < ApplicationController
  include CollectionsHelper,SearchContent

  def index
    acronym = params[:ontology]
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    ontology_not_found(acronym) if @ontology.nil?
    @submission = @ontology.explore.latest_submission(include:'uriRegexPattern,preferredNamespaceUri,naturalLanguage')
    collection_id = params[:collectionid]
    @collection = get_collection(@ontology, collection_id) if collection_id


    if params[:search].blank?
      @collections = get_collections(@ontology)

      render partial: 'collections/list_view'
    else

      query, page, page_size = helpers.search_content_params

      results, _, next_page, total_count = search_ontologies_content(query: query,
                                                                     page: page,
                                                                     page_size: page_size,
                                                                     filter_by_ontologies: [acronym],
                                                                     filter_by_types: ['Collection'])


      render inline: helpers.render_search_paginated_list(container_id: 'collections_sorted_list',
                                                          next_page_url: "/ontologies/#{@ontology.acronym}/collections",
                                                          child_url: "/ontologies/#{@ontology.acronym}/collections/show", child_turbo_frame: 'collection',
                                                          child_param: :collectionid,
                                                          results:  results, next_page:  next_page,
                                                          total_count: total_count
      )
    end
  end

  def show

    redirect_to(ontology_path(id: params[:ontology], p: 'collections', collectionid: params[:id], lang: request_lang)) and return unless turbo_frame_request?

    @collection = get_request_collection

    render partial: "collections/show"
  end

  def show_label
    collection_label = ''
    collection = get_request_collection
    collection_label = collection['prefLabel'] if collection
    collection_label = params[:id] if collection_label.nil? || collection_label.empty?

    label = helpers.main_language_label(collection_label)
    link = collection_path(collection_id: params[:id], ontology_id: params[:ontology_id], language: request_lang)
    render(inline: helpers.ajax_link_chip(params[:id], label, link, external: collection.blank?), layout: false)
  end

  def show_members
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id] || params[:ontology]).first
    ontology_not_found(params[:ontology_id] || params[:ontology]) if @ontology.nil? || @ontology.errors
    @submission = @ontology.explore.latest_submission(include: 'uriRegexPattern,preferredNamespaceUri,naturalLanguage')
    page = params[:page] || '1'
    @auto_click = page.to_s.eql?('1')
    @collection = get_request_collection(@ontology)

    if @collection
      @page = @collection.explore.members({ page: page, language: request_lang })
      @concepts = @page.collection
    else
      @page = OpenStruct.new({ nextPage: 1, page: 1 })
      @concepts = []
    end
    render partial: 'concepts/list'
  end

  private

  def get_request_collection(ontology = nil)
    params[:id] = request_collection_id

    return nil if params[:id].nil? || params[:id].empty?

    @ontology = ontology || LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id] || params[:ontology]).first
    ontology_not_found(params[:ontology_id]) if @ontology.nil?
    get_collection(@ontology, params[:id])
  end
end
