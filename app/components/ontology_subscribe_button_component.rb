# frozen_string_literal: true

class OntologySubscribeButtonComponent < ViewComponent::Base
  include InternationalisationHelper
  def initialize(id: '', ontology_id:, subscribed:, user_id:, count: 0, link: 'javascript:void(0);', subscription_id: nil, notification_type: 3)
    super
    @id = id
    @subscribed = subscribed
    @sub_text = subscribed ? t('components.unwatch') : t('components.watch')
    @link = link
    @count = count
    @notification_type = notification_type
    @controller_params = {
      data: {
        controller: "tooltip #{!user_id.nil? && 'subscribe-notes'}",
        'subscribe-notes-ontology-id-value': ontology_id,
        'subscribe-notes-is-subbed-value': subscribed.to_s,
        'subscribe-notes-user-id-value': user_id,
        'subscribe-notes-watch-value': t('components.watch'),
        'subscribe-notes-unwatch-value': t('components.unwatch'),
        'subscribe-notes-subscription-id-value': subscription_id,
        'subscribe-notes-notification-type-value': notification_type,
      },
      title: title
    }
  end

  def title
    if @subscribed
      t('components.resource', sub_text: @sub_text)
    elsif @count.zero?
      t('components.notified_of_all_updates')
    else
      t('components.join_the_count', count: @count)
    end
  end

  def data_turbo
    @link.include?('/login') ? 'false' : 'true'
  end
end
