class OntologiesAdministrationController < ApplicationController
  require 'multi_json'
  include OntologiesHelper
  layout 'ontology'

  before_action :authorize_ontology_admin
  # Ontology admins may not delete their ontology yet (agroportal/project-management#765)
  before_action :authorize_admin, only: :destroy

  def show
    render 'ontologies/admin'
  end

  def log
    log_url = "/ontologies/#{@ontology.acronym}/admin/log"
    @log = LinkedData::Client::HTTP.get(log_url)

    respond_to do |format|
      format.html do
        # Its status, as fresh as the submissions table, tells whether a step failed
        @latest_submission = @ontology.explore.latest_submission(include: 'submissionStatus', invalidate_cache: true)
        render partial: 'ontologies/admin/log', layout: false
      end
      # log.txt, the download button
      format.text { send_data log_text, filename: "#{@ontology.acronym}-latest-submission-log.txt" }
    end
  end

  def submissions
    render partial: 'ontologies/admin/submissions_table', locals: { ontology: @ontology }, layout: false
  end

  # Processing details of a submission, shown in the application modal
  def submission_status
    @submission = LinkedData::Client::HTTP.get("/ontologies/#{@ontology.acronym}/submissions/#{params[:id].to_i}",
                                               include: 'submissionId,submissionStatus')
    return head(:not_found) if @submission.submissionId.nil?

    render partial: 'ontologies/admin/submission_status', layout: false
  end

  def destroy
    acronym = @ontology.acronym
    page = ontology_administration_path(acronym)

    # The acronym typed in the caution zone, checked again here: a request
    # without it deletes nothing
    unless params[:confirmation].to_s.strip == acronym
      return redirect_to(page, alert: t('ontologies.admin.ontology.not_confirmed', acronym: acronym))
    end

    response = @ontology.delete
    if response_success?(response)
      redirect_to my_ontologies_path, notice: t('ontologies.admin.ontology.deleted', acronym: acronym)
    else
      redirect_to page, alert: t('ontologies.admin.ontology.error', acronym: acronym)
    end
  end

  def destroy_submission
    # Use bulk deletion endpoint for both single and multiple submissions
    ids = params[:ids] || [params[:id]]
    response = LinkedData::Client::HTTP.delete("/ontologies/#{@ontology.acronym}/submissions?ontology_submission_ids=#{ids.join(',')}")

    if response_success?(response)
      notice = t('ontologies.admin.submissions.submissions_deleted', submission_ids: ids.join(','))
      redirect_to ontology_administration_path(@ontology.acronym), notice: notice
    else
      redirect_to ontology_administration_path(@ontology.acronym), alert: response.body || t('ontologies.admin.submissions.error_deleting_submissions', message: response.body)
    end
  end

  private

  # One line per entry, as the page shows them:
  #   [2026-11-16 10:02:11] ERROR: Submission STY/2 failed: RDF
  def log_text
    return @log if @log.is_a?(String)

    # An API error is an object without message: it adds no line
    lines = Array(@log).map(&:to_h).filter_map do |entry|
      "[#{entry[:timestamp]}] #{entry[:severity]}: #{entry[:message]}" if entry[:message]
    end
    lines.join("\n")
  end

  def authorize_ontology_admin
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    redirect_to_home unless session[:user] && (@ontology.administeredBy.include?(session[:user].id) || session[:user].admin?)
  end
end
