class OntologiesAdministrationController < ApplicationController
  require 'multi_json'
  include OntologiesHelper
  # Saves the object description properties as the edit page saves a submission
  include SubmissionUpdater
  layout 'ontology'

  # viewingRestriction: everyone sees a public ontology; a private one, its
  # administrators and the accounts in its access list
  VISIBILITIES = %w[public private].freeze
  private_constant :VISIBILITIES

  before_action :authorize_ontology_admin

  def show
    # The Danger Zone lists the accounts allowed to see a private ontology
    @acl = ontology_acl
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

  # From the Danger Zone, the only page that changes it after creation
  def update_visibility
    acronym = @ontology.acronym
    visibility = params[:visibility]
    return head(:bad_request) unless VISIBILITIES.include?(visibility)

    response = @ontology.update(values: { viewingRestriction: visibility }, cache_refresh_all: false)
    if response_success?(response)
      redirect_to ontology_administration_path(acronym), notice: t("ontologies.admin.visibility.changed.#{visibility}", acronym: acronym)
    else
      redirect_to ontology_administration_path(acronym), alert: t('ontologies.admin.visibility.error', acronym: acronym)
    end
  end

  # Administrators see and modify the ontology, even private. The modal lists
  # every account, the current administrators selected
  def edit_administrators
    @users = user_options
    render partial: 'ontologies/admin/administrators', layout: false
  end

  # Replaces the administrators. The API requires one at least
  def update_administrators
    acronym = @ontology.acronym
    page = ontology_administration_path(acronym)
    administrators = Array(params[:administrators]).compact_blank
    return redirect_to(page, alert: t('ontologies.admin.administrators.none', acronym: acronym)) if administrators.empty?

    response = @ontology.update(values: { administeredBy: administrators }, cache_refresh_all: false)
    return redirect_to(page, alert: t('ontologies.admin.administrators.error', acronym: acronym)) unless response_success?(response)

    # Who removed themselves can no longer open this page: the ontology page instead
    page = ontology_path(acronym) unless administrators.include?(session[:user].id) || current_user_admin?
    redirect_to page, notice: t('ontologies.admin.administrators.saved', acronym: acronym)
  end

  # The object description properties of the latest submission, in their own
  # section of the page. The inputs come from the edit page (edit_properties)
  def object_description
    @submission_id = @ontology.explore.latest_submission(include: 'submissionId').submissionId
    @attributes = helpers.object_description_attributes
    render partial: 'ontologies/admin/object_description', layout: false
  end

  def update_object_description
    acronym = @ontology.acronym
    section = ontology_administration_path(acronym, section: t('ontologies.admin.sections.object_description').parameterize)

    # The attributes of the section only, whatever else the form sends
    values = submission_params(params[:submission] || ActionController::Parameters.new).slice(*helpers.object_description_attributes)
    _submission, response = update_submission(values.merge(ontology: acronym), params.require(:submission_id), @ontology)
    if response_error?(response)
      redirect_to section, alert: t('ontologies.admin.object_description.error', acronym: acronym)
    else
      redirect_to section, notice: t('ontologies.admin.object_description.saved', acronym: acronym)
    end
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

  # [username, user URI] pairs for a user picker, by username
  def user_options(except: [])
    LinkedData::Client::Models::User.all(include: 'username')
                                    .reject { |user| except.include?(user.id) }
                                    .map { |user| [user.username, user.id] }
                                    .sort_by { |username, _id| username.downcase }
  end

  # User URIs. The API leaves acl out of an ontology unless asked for it
  def ontology_acl
    Array(LinkedData::Client::HTTP.get("/ontologies/#{@ontology.acronym}", include: 'acl', invalidate_cache: true).acl)
  end

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
