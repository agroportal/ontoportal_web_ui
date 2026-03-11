class OntologiesMetadataCuratorController < ApplicationController
  include TurboHelper, SubmissionsHelper, ActionView::Helpers::FormHelper
  include SubmissionUpdater
  layout :determine_layout
  before_action :submission_metadata, only: [:result, :edit, :update, :show_metadata_by_ontology]

  def result
    start_time = Time.now
    @ontologies_ids = params[:ontology] ? Array(params[:ontology][:ontologyId]) : []
    @metadata_sel = params[:search] ? params[:search][:metadata] : []
    @submissions = []
    @ontologies = []
    select_all_ontologies = @ontologies_ids.empty?
    show_all_submissions = !params[:show_submissions].nil?
    return if @metadata_sel.empty?
    return if select_all_ontologies && show_all_submissions # To not overwhelm our server for getting all submissions of all ontologies

    ontology_display_attribute = equivalent_ontology_properties(@metadata_sel) + %w[acronym]

    if select_all_ontologies
      @ontologies = LinkedData::Client::Models::Ontology.all(display_links: false, display_context: false, include: ontology_display_attribute.join(','))
      @ontologies_ids = @ontologies.map(&:acronym)
    elsif !@ontologies_ids.nil? || !@ontologies_ids.empty?
      @ontologies_ids.each do |data|
        @ontologies << LinkedData::Client::Models::Ontology.find_by_acronym(data, {include: ontology_display_attribute.join(',')}).first
      end
    end

    return if @ontologies.empty?
    
    submission_display_attribute = equivalent_properties(@metadata_sel) + %w[submissionId]
    @hash = build_hash_submissions(show_all_submissions: show_all_submissions, display_attribute: submission_display_attribute)
    
    Rails.logger.info "Getting ontologies submission took: #{Time.now - start_time} seconds"

    respond_to do |format|
      format.html { redirect_to admin_index_path }
      format.turbo_stream { render turbo_stream: [
          replace("selection_metadata_form", partial: "ontologies_metadata_curator/metadata_table")
        ]
      }
    end
  end

  def show_metadata_by_ontology
    @acronym = params[:ontology]
    inline_save = params[:inline_save] && params[:inline_save].eql?('true')
    display_submission_attributes(@acronym, params[:properties]&.split(','),
                                  submissionId: params[:submission_id], inline_save: inline_save)
    render partial: 'submissions/form_content', locals: { id: params[:form_id] || '', acronym: @acronym, submissionId: params[:submission_id] }
  end

  def show_metadata_value
    acronym = params[:ontology]
    attribute = params[:attribute]
    submission_id = params[:submission_id]
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
    @submission = @ontology.explore.submissions({ display: "#{attribute},submissionId" }, submission_id)
    id = attribute_input_frame_id(acronym, submission_id, attribute)
    render_turbo_stream replace(id, partial: 'ontologies_metadata_curator/attribute', locals: { id: id, attribute: attribute, submission: @submission, ontology: @ontology })
  end

  def edit

    if params[:selected_acronyms].nil? || params[:selected_metadata].nil?
      render_turbo_stream alert_error(id: 'application_modal_content') { t('ontologies_metadata_curator.start_the_bulk_edit') }
      return
    end

    @selected_ontologies = params[:selected_acronyms].map { |x| ontology_and_submission_id(x) }
    @selected_metadata = params[:selected_metadata]
    @all_metadata = params[:all_metadata]
    render partial: 'ontologies_metadata_curator/form_edit'
  end

  def update
    @selected_ontologies = params[:selected_ontologies].map { |x| ontology_and_submission_id(x) }
    @active_ontology = ontology_and_submission_id(params[:active_ontology])
    @all_metadata = params[:all_metadata]&.split
    error_responses = []
    @submissions = []
    active_submission_data = params['submission']["#{@active_ontology[0]}_#{@active_ontology[1]}"]

    @selected_ontologies.each do |onto, sub_i|
      new_data = active_submission_data
      new_data[:ontology] = onto
      new_data[:id] = sub_i
      error_responses << update_submission(new_data, sub_i).last if new_data
      @submissions << @submission
    end

    errors = nil
    if error_responses.compact.any? { |x| x.status != 204 }
      errors = error_responses.map { |error_response| response_errors(error_response) }
    end
    respond_to do |format|
      format.turbo_stream do
        if errors
          render_turbo_stream(alert_error { errors.map { |e| e[:error] }.join(',') })
        else
          streams = [alert_success { t('ontologies_metadata_curator.alert_success_submissions') }]
          @submissions.each do |submission|
            submission.ontology = OpenStruct.new({ acronym: submission.ontology })
            streams << replace("#{ontology_submission_id_label(submission.ontology.acronym, submission.submissionId)}_row", partial: 'ontologies_metadata_curator/submission', locals: { submission: submission, attributes: @all_metadata })
          end
          render_turbo_stream(*streams)
        end
      end
    end
  end

  private


  def build_hash_submissions(show_all_submissions: false, display_attribute: [])
    acronym_ontolog_submissions_hash = {}
    
    if show_all_submissions
      @ontologies.each do |ontology|
        submissions = ontology.explore.submissions({ include: display_attribute.join(',') })
        acronym_ontolog_submissions_hash[ontology.acronym] = {
          ontology: ontology,
          submissions: submissions
        }
      end
    else
      # Get all submissions for the selected ontologies
      submissions = LinkedData::Client::Models::OntologySubmission.all(include_status: "any", acronym: @ontologies_ids.join('|'), display_links: false, display_context: false, include: display_attribute.join(','))
      submissions.reject! { |x| !@ontologies_ids.include?(x.id.split('/')[-3]) } unless @ontologies_ids.empty?
      # Filter and group submissions by ontology acronym
      submissions_by_ontology = submissions.group_by { |sub| sub.id.split('/')[-3] }     
      # Build the hash with the same structure
      @ontologies.each do |ontology|
        acronym_ontolog_submissions_hash[ontology.acronym] = {
          ontology: ontology,
          submissions: (submissions_by_ontology[ontology.acronym] || []).sort_by(&:id)
        }
      end
    end

    return acronym_ontolog_submissions_hash
  end

end
