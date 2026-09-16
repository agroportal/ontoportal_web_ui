require 'action_view'
include ActionView::Helpers::NumberHelper

class LandscapeController < ApplicationController
  layout :determine_layout
  helper FairScoreHelper
  include FairScoreHelper

  def index
    #@ontologies = LinkedData::Client::Models::Ontology.all(include_views: false)
    #@submissions = LinkedData::Client::Models::OntologySubmission.all(values: params[:submission])

    # Array with color codes for the pie charts. iterate color_index to change color
    pie_colors_array = ["#2484c1", "#0c6197", "#4daa4b", "#90c469", "#daca61", "#e4a14b", "#e98125", "#cb2121", "#830909", "#923e99", "#ae83d5", "#bf273e", "#ce2aeb", "#bca44a", "#618d1b", "#1ee67b", "#b0ec44", "#a4a0c9", "#322849", "#86f71a", "#d1c87f", "#7d9058", "#44b9b0", "#7c37c0", "#cc9fb1", "#e65414", "#8b6834", "#248838"];

    groups_count_hash = {}
    domains_count_hash = {}
    # A hash for counting ontologies in size ranges
    size_slices_hash = {}
    size_slices_hash["< 100"] = 0
    size_slices_hash["< #{number_with_delimiter(1000, delimiter: " ")}"] = 0
    size_slices_hash["< #{number_with_delimiter(10000, delimiter: " ")}"] = 0
    size_slices_hash["< #{number_with_delimiter(100000, delimiter: " ")}"] = 0
    size_slices_hash["100k+"] = 0

    natural_language_hash = {}
    licenseProperty_hash = {}
    formalityProperty_hash = {}
    isOfTypeProperty_hash = {}

    prefLabelProperty_hash = {}
    synonymProperty_hash = {}
    definitionProperty_hash = {}
    authorProperty_hash = {}

    people_count_hash = {}
    people_count_emails = {}
    engineering_tool_count = {}

    org_count_hash = {}

    ontology_relations_array = []

    ontologyFormatsCount = Hash.new(0).merge({"OWL" => 0, "SKOS" => 0, "UMLS" => 0, "OBO" => 0})

    @metrics_average = [{attr: "classes", label: t('landscape.classes'), array: []},
                        {attr: "individuals", label: t('landscape.individuals'), array: []},
                        {attr: "properties", label: t('landscape.properties'), array: []},
                        {attr: "maxDepth", label: t('landscape.max_depth'), array: []},
                        {attr: "maxChildCount", label: t('landscape.max_child_count'), array: []},
                        {attr: "averageChildCount", label: t('landscape.average_child_count'), array: []},
                        {attr: "classesWithOneChild", label: t('landscape.classes_with_one_child'), array: []},
                        {attr: "classesWithMoreThan25Children", label: t('landscape.classes_with_more_than_25_children'), array: []},
                        {attr: "classesWithNoDefinition", label: t('landscape.classes_with_no_definition'), array: []},
                        {attr: "numberOfAxioms", label: t('landscape.number_of_xioms_triples'), array: []}]

    # Attributes to include. To avoid to get everything and make it faster
    # They are also used to get the value of each property later in the controller
    # TODO: define here the attributes you want to retrieve to create visualization
    sub_attributes = [:submissionId, :ontology, :group, :hasDomain, :hasOntologyLanguage, :naturalLanguage, :hasLicense,
                      :hasFormalityLevel, :isOfType, :contact, :name, :email, :usedOntologyEngineeringTool]

    pref_properties_attributes = [:prefLabelProperty, :synonymProperty, :definitionProperty, :authorProperty]

    # Be careful, if you add attributes to those lists you will need to add them when generating the JSON for the tag clouds
    # org_count_json_cloud and people_count_json_cloud
    contributors_attr_list = [:hasContributor, :hasCreator, :curatedBy]
    org_attr_list = [:fundedBy, :endorsedBy, :publisher]

    @relations_array = ["omv:useImports", "door:isAlignedTo", "door:ontologyRelatedTo", "omv:isBackwardCompatibleWith", "omv:isIncompatibleWith", "door:comesFromTheSameDomain", "door:similarTo",
                        "door:explanationEvolution", "voaf:generalizes", "door:hasDisparateModelling", "dct:hasPart", "voaf:usedBy", "schema:workTranslation", "schema:translationOfWork"]
    # "omv:hasPriorVersion" has been removed from this list to generate

    # We need prefixes to display them, we remove them to call them in the include
    relations_attributes = @relations_array.map {|r| r.to_s.split(":")[1]}

    metrics_attributes = @metrics_average.map {|m| m[:attr]}

    # Concat all attributes array and generate a string separated with comma for include param
    all_attributes = sub_attributes.concat(contributors_attr_list).concat(org_attr_list)
                                   .concat(relations_attributes).concat([:metrics]).concat(pref_properties_attributes).join(",")


    # Special treatment for includedInDataCatalog: arrays with a lot of different values, so it trigger the SPARQL default
    # when we retrieve multiple attr with multiple values in the array, and make the request slower
    @submissions = LinkedData::Client::Models::OntologySubmission.all(include_status: "any", include_views: true, display_links: false, display_context: false, include: 'all')
    data_catalog_submissions = @submissions

    dataCatalog_count_hash = {}
    # Add our Portal to the dataCatalog list
    dataCatalog_count_hash[$ORG_SITE] = data_catalog_submissions.length
    # Set all data_catalog count to 0
    $DATA_CATALOG_VALUES.map {|uri,name| dataCatalog_count_hash[name] = 0}
    data_catalog_submissions.each do |catalog_sub|
      catalog_sub.includedInDataCatalog.each do |data_catalog|
        $DATA_CATALOG_VALUES.each do |uri, name|
          if data_catalog[uri]
            dataCatalog_count_hash[name] += 1
          end
        end
      end
    end

    # Iterate ontologies to get the submissions with all metadata
    @submissions.each do |sub|
      ont = sub.ontology

      if !sub.nil?
        # Get hash of natural language use
        if !sub.naturalLanguage.nil? && !sub.naturalLanguage.empty?
          sub.naturalLanguage.each do |sub_lang|
            # replace lexvo URI by lexvo prefix
            prefixed_sub_lang = sub_lang
            if sub_lang.start_with?("http://lexvo.org/id/iso639-3/")
              prefixed_sub_lang = sub_lang.sub("http://lexvo.org/id/iso639-3/", "lexvo:")
            end
            # If lang already in hash then we increment the count of the lang in the hash
            if natural_language_hash.has_key?(prefixed_sub_lang.to_s)
              natural_language_hash[prefixed_sub_lang.to_s]["count"] = natural_language_hash[prefixed_sub_lang.to_s]["count"] + 1
            else
              natural_language_hash[prefixed_sub_lang.to_s] = {}
              natural_language_hash[prefixed_sub_lang.to_s]["count"] = 1
              natural_language_hash[prefixed_sub_lang.to_s]["uri"] = sub_lang
            end
          end
        end

        licenseProperty_hash = get_used_properties(sub.hasLicense, nil, licenseProperty_hash)

        formalityProperty_hash = get_used_properties(sub.hasFormalityLevel, nil, formalityProperty_hash)

        isOfTypeProperty_hash = get_used_properties(sub.isOfType, nil, isOfTypeProperty_hash)

        # Get the prefLabelProperty used for OWL properties in a hash
        if sub.hasOntologyLanguage.eql?("OWL")
          prefLabelProperty_hash = get_used_properties(sub.prefLabelProperty, "http://www.w3.org/2004/02/skos/core#prefLabel", prefLabelProperty_hash)

          synonymProperty_hash = get_used_properties(sub.synonymProperty, "http://www.w3.org/2004/02/skos/core#altLabel", synonymProperty_hash)

          definitionProperty_hash = get_used_properties(sub.definitionProperty, "http://www.w3.org/2004/02/skos/core#definition", definitionProperty_hash)

          authorProperty_hash = get_used_properties(sub.authorProperty, "http://purl.org/dc/elements/1.1/creator", authorProperty_hash)
        end

        get_metrics_for_average(sub)

        # Count the number of classes (individuals for skos by ontologies) to get number of ontologies by slice of size
        if sub.hasOntologyLanguage.eql?("SKOS")
          ontology_size = sub.metrics&.individuals || 0
        else
          ontology_size = sub.metrics&.classes || 0
        end
        if (!ontology_size.nil?)
          if (ontology_size >= 100000)
            size_slices_hash["100k+"] += 1
          else
            [100, 1000, 10000, 100000].each do |slice_size|
              if (ontology_size < slice_size)
                size_slices_hash["< #{number_with_delimiter(slice_size, delimiter: " ")}"] += 1
                break;
              end
            end
          end
        end

        # Get number of ontologies for each format (for horizontal bar chart)
        ontologyFormatsCount[sub.hasOntologyLanguage] += 1

        # Count number of ontologies for each group (bar chart)
        ont.group.each do |group|
          group_acro = group.to_s.split("/")[-1]
          if groups_count_hash.has_key?(group_acro)
            groups_count_hash[group_acro] += 1
          else
            groups_count_hash[group_acro] = 1
          end
        end

        # Count number of ontologies for each domain (bar chart)
        ont.hasDomain.each do |domain|
          domain_acro = domain.to_s.split("/")[-1]
          if domains_count_hash.has_key?(domain_acro)
            domains_count_hash[domain_acro] += 1
          else
            domains_count_hash[domain_acro] = 1
          end
        end

        # Get the count for usedOntologyEngineeringTool (to create a tag cloud)
        Array(sub.usedOntologyEngineeringTool).each do |tool|
          if engineering_tool_count.key?(tool)
            engineering_tool_count[tool] += 1
          else
            engineering_tool_count[tool] = 1
          end
        end

        # Get people that are mentioned as ontology actors (contact, contributors, creators, curator) to create a tag cloud
        # hasContributor hasCreator contact(explore,name) curatedBy
        contributors_attr_list.each do |contributor_attr|
          contributors = sub.send(contributor_attr.to_s)
          Array(contributors).each do |contributor|
            contrib = contributor.name || contributor.to_s
            if people_count_hash.has_key?(contrib)
              people_count_hash[contrib][contributor_attr] += 1
            else
              # Create the contributor entry in the Hash and create the attr entries that will be incremented
              people_count_hash[contrib] = {}
              people_count_hash[contrib][:contact] = 0
              contributors_attr_list.each do |create_contributor_attr|
                people_count_hash[contrib][create_contributor_attr] = 0
              end
              people_count_hash[contrib][contributor_attr] += 1
            end
          end
        end
        sub.contact.each do |contact|
          contributor_label = contact.name
          unless contributor_label.nil?
            if people_count_hash.has_key?(contributor_label)
              people_count_hash[contributor_label][:contact] += 1
            else
              # Create the contrinutor entry in the Hash and create the attr entries that will be incremented
              people_count_hash[contributor_label] = {}
              people_count_hash[contributor_label][:contact] = 0
              contributors_attr_list.each do |create_contributor_attr|
                people_count_hash[contributor_label][create_contributor_attr] = 0
              end
              people_count_hash[contributor_label][:contact] += 1
            end
            people_count_emails[contributor_label] = contact.email unless contact.email.nil?
          end
        end

        org_attr_list.each do |org_attr|
          # If the attribute object is not a list we make it a list of the single object we get
          organizations_list = Array(sub.send(org_attr.to_s))

          organizations_list.each do |org|
            org_str = org.name || org.to_s rescue org.to_s
            org_uri = nil
            # Check if the organization is actually an URL
            if org_str =~ /\A#{URI::regexp}\z/
              org_uri = org_str
              # Remove http, www and last / from URI
              org_str = org_str.sub("http://", "").sub("https://", "").sub("www.", "")
              org_str = org_str[0..-2] if org_str.last.eql?("/")
            end

            if org_count_hash.has_key?(org_str)
              org_count_hash[org_str][org_attr] += 1
            else
              # Create the contrinutor entry in the Hash and create the attr entries that will be incremented
              org_count_hash[org_str] = {}
              org_attr_list.each do |create_org_attr|
                org_count_hash[org_str][create_org_attr] = 0
              end
              org_count_hash[org_str][:uri] = org_uri unless org_uri.nil?
              org_count_hash[org_str][org_attr] += 1
            end
          end
        end

        # Get ontology relations between each other (ex: STY isAlignedTo GO)
        @relations_array.each do |relation_attr|
          relation_values = sub.send(relation_attr.to_s.split(":")[1])
          if !relation_values.nil? && !relation_values.empty?
            if !relation_values.kind_of?(Array)
              relation_values = [relation_values]
            end
            relation_values.each do |relation_value|
              target_id = relation_value
              target_in_portal = false
              target_ont = nil
              # if we find our portal URL in the ontology URL, then we just keep the ACRONYM to try to get the ontology.
              if relation_value.include?(helpers.portal_name)
                relation_value = relation_value.split('/').last
                target_ont = LinkedData::Client::Models::Ontology.find_by_acronym(relation_value).first
              end

              # Use acronym to get ontology from the portal
              if target_ont
                target_id = target_ont.acronym
                target_in_portal = true
              end
              ontology_relations_array.push({ source: ont.acronym, target: target_id, relation: relation_attr.to_s, targetInPortal: target_in_portal })
            end
          end
        end
      end
    end

    # Add value of metrics to the @metrics_average hash
    @metrics_average.each do |metrics|
      metrics[:average] = (metrics[:array].sum / metrics[:array].size.to_f).round(2)
    end


    notes_people_count_hash = {}
    notes_ontologies_count_hash = {}

    # Retrieve user and ontologies from Reviews, Projects and Notes
    reviews = LinkedData::Client::Models::Review.all
    reviews.each do |review|
      notes_people_count_hash = notes_create_hash_entry(review.creator, :reviews, notes_people_count_hash)
      notes_ontologies_count_hash = notes_create_hash_entry(review.ontologyReviewed, :reviews, notes_ontologies_count_hash)
    end

    projects = LinkedData::Client::Models::Project.all
    projects.each do |project|
      project.creator.each do |creator|
        notes_people_count_hash = notes_create_hash_entry(creator, :projects, notes_people_count_hash)
      end
      project.ontologyUsed.each do |onto_used|
        notes_ontologies_count_hash = notes_create_hash_entry(onto_used, :projects, notes_ontologies_count_hash)
      end
    end

    notes = LinkedData::Client::Models::Note.all
    notes.each do |note|
      notes_people_count_hash = notes_create_hash_entry(note.creator, :notes, notes_people_count_hash)
      note.relatedOntology.each do |related_onto|
        notes_ontologies_count_hash = notes_create_hash_entry(related_onto, :notes, notes_ontologies_count_hash)
      end
    end

    # Build the array of hashes used to create the Tag cloud
    notes_ontologies_json_cloud = []
    notes_people_json_cloud = []

    notes_people_count_hash.each do |people,hash_counts|
      # Random color for each word in the cloud
      colour = "%06x" % (rand * 0xffffff)
      title_array = []
      total_count = 0
      if hash_counts.has_key?(:projects)
        title_array.push(t('landscape.projects_count', count: hash_counts[:projects]))
        total_count += hash_counts[:projects]
      end
      if hash_counts.has_key?(:notes)
        title_array.push(t('landscape.notes_count', count: hash_counts[:notes]))
        total_count += hash_counts[:notes]
      end
      if hash_counts.has_key?(:reviews)
        title_array.push(t('landscape.reviews_count', count: hash_counts[:reviews]))
        total_count += hash_counts[:reviews]
      end
      if total_count > 0
        notes_people_json_cloud.push({"text"=>people.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_array.join(", ")}, "link" => hash_counts[:uri]})
      end
    end

    notes_ontologies_count_hash.each do |onto,hash_counts|
      # Random color for each word in the cloud
      colour = "%06x" % (rand * 0xffffff)
      title_array = []
      total_count = 0
      if hash_counts.has_key?(:projects)
        title_array.push(t('landscape.projects_count', count: hash_counts[:projects]))
        total_count += hash_counts[:projects]
      end
      if hash_counts.has_key?(:notes)
        title_array.push(t('landscape.notes_count', count: hash_counts[:notes]))
        total_count += hash_counts[:notes]
      end
      if hash_counts.has_key?(:reviews)
        title_array.push(t('landscape.reviews_count', count: hash_counts[:reviews]))
        total_count += hash_counts[:reviews]
      end
      if total_count > 0
        notes_ontologies_json_cloud.push({"text"=>onto.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_array.join(", ")}, "link" => hash_counts[:uri]})
      end
    end

    # Generate the JSON to put natural languages in the pie chart
    natural_language_json_pie = []
    licenseProperty_json_pie = []

    prefLabelProperty_json_pie = []
    synonymProperty_json_pie = []
    definitionProperty_json_pie = []
    authorProperty_json_pie = []

    # Get the different people and organizations to generate a tag cloud
    people_count_json_cloud = []
    people_count_hash.each do |people,hash_count|
      # Random color for each word in the cloud
      colour = "%06x" % (rand * 0xffffff)
      title_array = []
      total_count = 0
      if hash_count[:contact] > 0
        title_array.push(t('landscape.as_contact_count', count: hash_count[:contact]))
        total_count += hash_count[:contact]
      end
      if hash_count[:hasContributor] > 0
        title_array.push(t('landscape.as_contributor_count', count: hash_count[:hasContributor]))
        total_count += hash_count[:hasContributor]
      end
      if hash_count[:hasCreator] > 0
        title_array.push(t('landscape.as_creator_count', count: hash_count[:hasCreator]))
        total_count += hash_count[:hasCreator]
      end
      if hash_count[:curatedBy] > 0
        title_array.push(t('landscape.as_curator_count', count: hash_count[:curatedBy]))
        total_count += hash_count[:curatedBy]
      end
      title_str = t('landscape.contributions', title: title_array.join(", "))

      if total_count > 1
        if people_count_emails[people.to_s].nil?
          people_count_json_cloud.push({"text"=>people.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_str}})
        else
          people_count_json_cloud.push({"text"=>people.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_str}, "link" => "mailto:#{people_count_emails[people.to_s]}"})
        end
      end
    end

    org_count_json_cloud = []
    org_count_hash.each do |org,hash_count|
      # Random color for each word in the cloud
      colour = "%06x" % (rand * 0xffffff)
      title_array = []
      total_count = 0
      if hash_count[:publisher] > 0
        title_array.push(t('landscape.published_ontologies', count: hash_count[:publisher]))
        total_count += hash_count[:publisher]
      end
      if hash_count[:fundedBy] > 0
        title_array.push( t('landscape.funded_ontologies', count: hash_count[:fundedBy]))
        total_count += hash_count[:fundedBy]
      end
      if hash_count[:endorsedBy] > 0
        title_array.push( t('landscape.endorsed_ontologies', count: hash_count[:endorsedBy]))
        total_count += hash_count[:endorsedBy]
      end
      title_str = t('landscape.contributions', title: title_array.join(", "))

      if total_count > 1
        if hash_count.has_key?(:uri)
          org_count_json_cloud.push({"text"=>org.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_str}, "link" => "#{hash_count[:uri]}"})
        else
          org_count_json_cloud.push({"text"=>org.to_s,"weight"=>total_count, "html" => {style: "color: ##{colour};", title: title_str}})
        end
      end
    end

    engineering_tool_cloud_json = []
    engineering_tool_count.each do |tool,count|
      # Random color for each word in the cloud
      colour = "%06x" % (rand * 0xffffff)
      engineering_tool_cloud_json.push({"text"=>tool.to_s,"weight"=>count, "html" => {style: "color: ##{colour};", title: "Used to build #{count.to_s} ontologies."}})
    end

    # Push the results in hash formatted for the Javascript lib that will be displaying it
    color_index = 0
    natural_language_hash.each do |lang,count_hash|
      natural_language_json_pie.push({"label"=>lang.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 1
    end

    color_index = 0
    licenseProperty_hash.each do |license,count_hash|
      licenseProperty_json_pie.push({"label"=>license.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 1
    end

    formalityLevelCount = {}
    formalityProperty_hash.each do |formality_level,count_hash|
      # Generate formalityLevel JSON used to get the bar charts
      formalityLevelCount[formality_level.to_s] = count_hash["count"]
    end

    isOfTypeCount = {}
    isOfTypeProperty_hash.each do |isOfType,count_hash|
      isOfTypeCount[isOfType.to_s] = count_hash["count"]
    end

    color_index = 0
    prefLabelProperty_hash.each do |pref_label,count_hash|
      prefLabelProperty_json_pie.push({"label"=>pref_label.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 2
    end
    color_index = 1
    synonymProperty_hash.each do |synonym,count_hash|
      synonymProperty_json_pie.push({"label"=>synonym.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 2
    end
    color_index = 0
    definitionProperty_hash.each do |definition,count_hash|
      definitionProperty_json_pie.push({"label"=>definition.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 2
    end
    color_index = 1
    authorProperty_hash.each do |author,count_hash|
      authorProperty_json_pie.push({"label"=>author.to_s,"value"=>count_hash["count"], "color"=>pie_colors_array[color_index], "uri"=>count_hash["uri"]})
      color_index += 2
    end

    # Format the ontologyFormatsCount hash as the JSON needed to generate the chart
    ontologyFormatsChartJson = { labels: ontologyFormatsCount.keys,
                                 datasets: [{ label: t('landscape.number_of_ontologies_using_format'),
                                                 data: ontologyFormatsCount.values,
                                                 backgroundColor: pie_colors_array[3]}] }

    isOfTypeChartJson = { labels: isOfTypeCount.keys,
                          datasets: [{ label: t('landscape.number_of_ontologies_of_type'),
                                          data: isOfTypeCount.values,
                                          backgroundColor: pie_colors_array[0]}] }

    formalityLevelChartJson = { labels: formalityLevelCount.keys,
                                datasets: [{ label: t('landscape.number_of_ontologies_of_formality_level'),
                                                data: formalityLevelCount.values,
                                                backgroundColor: pie_colors_array[2]}] }

    dataCatalogChartJson = { labels: dataCatalog_count_hash.keys,
                             datasets: [{ label: t('landscape.number_of_ontologies_in_catalog'), data: dataCatalog_count_hash.values,
                                                backgroundColor: pie_colors_array[5]}] }

    # Format the groupOntologiesCount hash as the JSON needed to generate the chart
    groupCountChartJson = { labels: groups_count_hash.keys,
                            datasets: [{ label: t('landscape.number_of_ontologies'), data: groups_count_hash.values,
                                                  backgroundColor: pie_colors_array[3]}] }

    domainCountChartJson = { labels: domains_count_hash.keys,
                             datasets: [{ label: t('landscape.number_of_ontologies'), data: domains_count_hash.values,
                                             backgroundColor: pie_colors_array[4]}] }

    # Format the groupOntologiesCount hash as the JSON needed to generate the chart
    sizeSlicesChartJson = { labels: size_slices_hash.keys,
                            datasets: [{ label: t('landscape.number_of_ontologies_with_class_count_in_range'),
                                            data: size_slices_hash.values,
                                            backgroundColor: pie_colors_array[2]}] }

    # Also pass groups and hasDomain name to resolve it and better label of bar charts
    groups = LinkedData::Client::Models::Group.all(include: "acronym,name,description")
    domains = LinkedData::Client::Models::Category.all(include: "acronym,name,description")

    groups_info_hash = {}
    groups.each do |group|
      groups_info_hash[group.acronym] = {}
      groups_info_hash[group.acronym][:id] = group.id
      groups_info_hash[group.acronym][:name] = group.name
      groups_info_hash[group.acronym][:description] = []
      # Slice the description in 6 words string to avoid too long sentence in the bar chart tooltip in js
      group.description.split(" ").each_slice(6) {|slice| groups_info_hash[group.acronym][:description].push(slice.join(" ")) } if group.description
    end

    domains_info_hash = {}
    domains.each do |domain|
      domains_info_hash[domain.acronym] = {}
      domains_info_hash[domain.acronym][:id] = domain.id
      domains_info_hash[domain.acronym][:name] = domain.name
      domains_info_hash[domain.acronym][:description] = []
      # Slice the description in 6 words string to avoid too long sentence in the bar chart tooltip in js
      domain.description.split(" ").each_slice(6) {|slice| domains_info_hash[domain.acronym][:description].push(slice.join(" ")) } if domain.description
    end

    @landscape_data = {
      people_count_json_cloud: people_count_json_cloud,
      org_count_json_cloud: org_count_json_cloud,
      engineering_tool_cloud_json: engineering_tool_cloud_json,
      notes_ontologies_json_cloud: notes_ontologies_json_cloud,
      notes_people_json_cloud: notes_people_json_cloud,
      natural_language_json_pie: natural_language_json_pie,
      licenseProperty_json_pie: licenseProperty_json_pie,
      ontology_relations_array: ontology_relations_array,
      prefLabelProperty_json_pie: prefLabelProperty_json_pie,
      synonymProperty_json_pie: synonymProperty_json_pie,
      definitionProperty_json_pie: definitionProperty_json_pie,
      authorProperty_json_pie: authorProperty_json_pie,
      ontologyFormatsChartJson: ontologyFormatsChartJson,
      isOfTypeChartJson: isOfTypeChartJson,
      formalityLevelChartJson: formalityLevelChartJson,
      dataCatalogChartJson: dataCatalogChartJson,
      groupCountChartJson: groupCountChartJson,
      groupsInfoHash: groups_info_hash,
      domainCountChartJson: domainCountChartJson,
      domainsInfoHash: domains_info_hash,
      sizeSlicesChartJson: sizeSlicesChartJson
    }.to_json.html_safe

  end

  private
  # For notes takes the hash and create the entry if not already existing
  # To create hash like this: {"user1": {"reviews": 3, "notes": 4, "projects": 4}}
  def notes_create_hash_entry(uri_id, notes_type, hash)
    id = uri_id.split('/').last
    if !hash.has_key?(id)
      hash[id] = {uri: uri_id}
    end
    if !hash[id].has_key?(notes_type)
      hash[id][notes_type] = 1
    else
      hash[id][notes_type] += 1
    end
    return hash
  end


  ##
  # Add metrics metadata from the param sub to the @metrics_average var to get the average for each metrics
  def get_metrics_for_average(sub)
    # Adding metrics to their arrays
    metrics = sub.send(:metrics)
    @metrics_average.each do |m|
      if metrics.nil? || metrics.send(m[:attr]).nil?
        m[:array].push(0)
      else
        m[:array].push(metrics.send(m[:attr]))
      end

    end
  end

  ##
  # Increment the hash entry for the property used by the submission for the given attribute
  # If null it increments the value for the default_property (for prefLabel prop or synonym prop for example)
  def get_used_properties(attr_value, default_property, property_hash)
    if attr_value.nil? || attr_value.empty?
      # if property null then we increment the default value
      if default_property.nil?
        return property_hash
      end
      attr_value = default_property
    else
      attr_value = attr_value.to_s
    end

    # Replace namespace by prefix (defined in application_controller.rb)
    prefixed_attr_value = attr_value
    RESOLVE_NAMESPACE.each do |prefix, namespace|
      if attr_value.start_with?(namespace)
        prefixed_attr_value = attr_value.sub(namespace, "#{prefix}:")
        break;
      end
    end

    # If attribute value property already in hash then we increment the count of the property in the hash
    if property_hash.has_key?(prefixed_attr_value)
      property_hash[prefixed_attr_value]["count"] += 1
    else
      property_hash[prefixed_attr_value] = {}
      property_hash[prefixed_attr_value]["count"] = 1
      property_hash[prefixed_attr_value]["uri"] = attr_value
    end
    return property_hash
  end
end
