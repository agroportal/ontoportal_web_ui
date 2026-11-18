class StatisticsController < ApplicationController
  include StatisticsHelper, ComponentsHelper

  layout :determine_layout

  def index
    @merged_data, @year_month_visits = statistics_cache.fetch("statistics_index_data-#{$SITE}", expires_in: 24.hours) do
      projects = LinkedData::Client::Models::Project.all({include: 'created'})
      users = LinkedData::Client::Models::User.all({include: 'created'})
      agents = LinkedData::Client::Models::Agent.all({include: 'created'})
      year_month_count, year_month_visits = ontologies_by_year_month

      users_grouped = group_by_year_month(users)
      projects_grouped = group_by_year_month(projects)

      fallback = [users_grouped.keys.first,
                  projects_grouped.keys.first,
                  year_month_count.keys.sort.first].compact.min
      agents_grouped = group_by_year_month(agents, fallback: fallback)

      merged_data = merge_time_evolution_data([users_grouped,
                                               projects_grouped,
                                               year_month_count,
                                               agents_grouped])

      [merged_data, year_month_visits]
    end
  end

  private

  # Slice requests send NCBO-Slice: the API scopes the data to the slice's
  # ontologies. Only the main domain fills the portal-wide cache.
  def statistics_cache
    @subdomain_filter[:active] ? ActiveSupport::Cache::NullStore.new : Rails.cache
  end
end
