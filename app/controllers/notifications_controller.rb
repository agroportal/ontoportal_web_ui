class NotificationsController < ApplicationController
  before_action :authorize_and_redirect, only: [:all]
  layout :determine_layout

  def list
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    per_page = 5
    
    begin
      url = "#{rest_url}/notifications"
      response = LinkedData::Client::HTTP.get(url, { page: page, pagesize: per_page, apikey: get_apikey })

      if response.is_a?(Array)
        @notifications = response.take(per_page)
        @next_page = response.size >= per_page ? page + 1 : nil
      else
        @notifications = []
        @next_page = nil
      end
    rescue => e
      Rails.logger.error "Failed to fetch notifications: #{e.message}"
      @notifications = []
      @next_page = nil
    end
    @current_page = page
    render layout: nil
  end

  def index
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 20

    @show_all = false

    begin
      url = "#{rest_url}/notifications"
      response = LinkedData::Client::HTTP.get(url, { page: @page, pagesize: @per_page, apikey: get_apikey, show_all: @show_all })

      if response.is_a?(Array)
        @notifications = response.take(@per_page)
        @next_page = response.size >= @per_page ? @page + 1 : nil
      else
        @notifications = []
        @next_page = nil
      end
    rescue => e
      Rails.logger.error "Failed to fetch notifications: #{e.message}"
      @notifications = []
      @next_page = nil
    end
    @current_page = @page
    @title = t('notifications.notifications')
  end

  def status
    begin
      url = "#{rest_url}/notifications/status"
      response = LinkedData::Client::HTTP.get(url, { apikey: get_apikey })
      
      @status = {
        has_unseen: response.has_unseen,
        count: response.count
      }
    rescue => e
      Rails.logger.error "Failed to fetch notification status: #{e.message}"
      @status = { has_unseen: false, count: 0 }
    end
    render layout: false
  end
end
