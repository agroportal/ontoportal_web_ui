class OntologiesAdministrationController < ApplicationController
  require 'multi_json'
  include OntologiesHelper
  layout 'ontology'

  before_action :authorize_ontology_admin

  def show
    # Its processing logs show only when a step failed
    @latest_submission = @ontology.explore.latest_submission(include: 'submissionStatus')
    render 'ontologies/admin'
  end

  def log
    log_url = "/ontologies/#{@ontology.acronym}/admin/log"
    @log = LinkedData::Client::HTTP.get(log_url)
    render partial: 'ontologies/admin/log', layout: false
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
    response = @ontology.delete
    if response_success?(response)
      redirect_to my_ontologies_path, notice: "Ontology deleted successfully"
    else
      redirect_to ontology_administration_path(@ontology.acronym), alert: "Error deleting ontology"
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

  def authorize_ontology_admin
    @ontology = LinkedData::Client::Models::Ontology.find_by_acronym(params[:ontology_id]).first
    redirect_to_home unless session[:user] && (@ontology.administeredBy.include?(session[:user].id) || session[:user].admin?)
  end
end
