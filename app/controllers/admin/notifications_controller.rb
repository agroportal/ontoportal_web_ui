class Admin::NotificationsController < AdminController
  def index
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @per_page = 20

    @show_all = if params.key?(:show_all)
                  params[:show_all].to_s == "true"
                else
                  true
                end

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
      Rails.logger.error "Failed to fetch admin notifications: #{e.message}"
      @notifications = []
      @next_page = nil
    end

    render layout: false if request.xhr? || params[:turbo_frame]
  end
end
