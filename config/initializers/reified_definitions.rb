# frozen_string_literal: true

# See ontoportal/ontoportal_web_ui#67.
#
# A reified definition is stored as its own RDF node; the flat `definition`
# attribute only returns that node's URI. The resolved node - carrying the
# definition text (`value`) and its provenance (`source`, `created`,
# `modified`) - is exposed by the API as the `definitionXl` attribute (the
# same pattern as `prefLabelXl` for SKOS-XL labels).
#
# The API client expands `full: true` into a hardcoded `include` list
# (`LinkedData::Client::Models::Class.include_attrs_full`) that does not mention
# `definitionXl`, so it is never fetched. Append it here - once, idempotently -
# so every detailed class load (concept show / details panes) resolves it and
# DefinitionsComponent can render definition provenance. The lighter non-full
# include list used for tree/browse fetches is left untouched.
Rails.application.config.after_initialize do
  klass = LinkedData::Client::Models::Class
  full = klass.include_attrs_full
  if full.is_a?(String) && full.split(',').map(&:strip).exclude?('definitionXl')
    klass.include_attrs_full = "#{full},definitionXl"
  end
rescue StandardError => e
  Rails.logger.warn("[reified_definitions] could not extend Class include attrs: #{e.message}")
end
