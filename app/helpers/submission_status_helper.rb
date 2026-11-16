# frozen_string_literal: true

# Processing state of a submission. The admin submissions table shows it as a
# pill, in the colors of the banner atop the ontology page; clicking the pill
# opens the outcome of each stage and step in a modal.
#
#   ( ✓ Ready )  ( ✗ Failed at Parse )  ( ⚠ Failed at Metrics )  ( i Not parsed )  ( Archived )
#      green             red                    orange                  blue           grey
module SubmissionStatusHelper
  Stage = Struct.new(:name, :outcome, :steps)
  Step = Struct.new(:code, :outcome, :description)

  # Stages in pipeline order, with the status codes of their steps. A step
  # adds its code when it succeeds, ERROR_<code> when it fails.
  STAGES = {
    parse: %w[UPLOADED TDV5 RDF RDF_LABELS OBSOLETE],
    index: %w[INDEXED INDEXED_PROPERTIES INDEXED_ALL_DATA],
    metrics: %w[METRICS],
    annotator: %w[ANNOTATOR],
    diff: %w[DIFF],
    fair: %w[FAIRNESS_FOOPS]
  }.freeze
  # The TDv5 check of an XLSX upload only reports failures
  ERROR_ONLY_STEPS = %w[TDV5].freeze
  # Ready as the API defines it (SubmissionStatus.get_ready_status)
  READY_STEP = 'RDF'
  ARCHIVED = 'ARCHIVED'
  ERROR_PREFIX = 'ERROR_'
  FAILED_STATES = %i[failed partly_failed].freeze
  # Icons of the banner atop the ontology page; archived submissions get none
  STATE_ICONS = { ready: 'success.svg', failed: 'danger.svg', partly_failed: 'warning.svg',
                  not_parsed: 'info.svg' }.freeze
  ICONS = { done: 'icons/success-icon.svg', failed: 'icons/error-icon.svg' }.freeze
  ICON_SIZE = '16'
  I18N_SCOPE = 'ontologies.admin.submissions.processing'
  private_constant :Stage, :Step, :STAGES, :ERROR_ONLY_STEPS, :READY_STEP, :ARCHIVED, :ERROR_PREFIX,
                   :FAILED_STATES, :STATE_ICONS, :ICONS, :ICON_SIZE, :I18N_SCOPE

  # The pill of the submissions table; opens the details in the application modal
  def submission_state_pill(submission, details_url)
    codes = status_codes(submission)
    state = submission_state(submission)
    icon = STATE_ICONS[state] && icon_svg(STATE_ICONS[state], aria_hidden: true)
    title = t('title', scope: I18N_SCOPE, id: submission.submissionId)

    link_to_modal(nil, details_url, class: "submission-state submission-state--#{state}",
                                    data: { show_modal_title_value: title }) do
      safe_join([icon, tag.span(state_label(state, codes))].compact)
    end
  end

  # One sentence on the overall state, atop the details
  def submission_state_summary(submission)
    t("summaries.#{submission_state(submission)}", scope: I18N_SCOPE)
  end

  # A step failed: the pill, like the banner atop the ontology page, is red or orange
  def submission_failed?(submission)
    return false unless submission

    FAILED_STATES.include?(submission_state(submission))
  end

  # Every stage with the outcome of its steps; none for an archived submission
  def submission_stages(submission)
    codes = status_codes(submission)
    return [] if codes.include?(ARCHIVED)

    stages = STAGES.map { |stage, steps| build_stage(stage, steps, codes) }
    unknown = unknown_steps(codes)
    stages << build_stage(:other, unknown, codes) if unknown.any?
    stages
  end

  # ✓ done, ✗ failed, ○ not run
  def processing_icon(outcome)
    label = t("outcomes.#{outcome}", scope: I18N_SCOPE)
    return tag.span(class: 'processing-not-run', role: 'img', title: label, 'aria-label': label) if outcome == :not_run

    icon_svg(ICONS[outcome], title: label, aria: true)
  end

  private

  def status_codes(submission)
    Array(submission.submissionStatus).map { |status| status.to_s.split('/').last }
  end

  # Same rule as the banner atop the ontology page (not_ready_submission_alert):
  # failed before parsing, partly failed after
  def submission_state(submission)
    codes = status_codes(submission)
    return :archived if codes.include?(ARCHIVED)

    status = status_string(submission)
    return :failed if submission_status_error?(status)
    return :partly_failed if submission_status_warning?(status)
    return :ready if codes.include?(READY_STEP)

    :not_parsed
  end

  # "Failed at Index": the first stage with a failed step
  def state_label(state, codes)
    return t("states.#{state}", scope: I18N_SCOPE) unless FAILED_STATES.include?(state)

    failed_stage = STAGES.find { |_, steps| steps.any? { |step| codes.include?(ERROR_PREFIX + step) } }&.first
    return t('states.failed', scope: I18N_SCOPE) unless failed_stage

    t('states.failed_at', scope: I18N_SCOPE, stage: t("stages.#{failed_stage}", scope: I18N_SCOPE))
  end

  def build_stage(stage, steps, codes)
    steps = steps.map { |step| build_step(step, codes) }
    steps = steps.reject { |step| step.outcome == :not_run && ERROR_ONLY_STEPS.include?(step.code) }

    Stage.new(t("stages.#{stage}", scope: I18N_SCOPE), stage_outcome(steps), steps)
  end

  def build_step(step, codes)
    Step.new(step, step_outcome(step, codes), t("steps.#{step.downcase}", scope: I18N_SCOPE, default: ''))
  end

  # Codes no stage knows, e.g. from a newer API
  def unknown_steps(codes)
    known = STAGES.values.flatten
    codes.map { |code| code.delete_prefix(ERROR_PREFIX) }.uniq.reject { |step| known.include?(step) }
  end

  def step_outcome(step, codes)
    return :failed if codes.include?(ERROR_PREFIX + step)
    return :done if codes.include?(step)

    :not_run
  end

  def stage_outcome(steps)
    outcomes = steps.map(&:outcome)
    return :failed if outcomes.include?(:failed)
    return :done if outcomes.include?(:done)

    :not_run
  end

  def icon_svg(path, **options)
    inline_svg_tag(path, width: ICON_SIZE, height: ICON_SIZE, **options)
  end
end
