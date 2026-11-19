module UrlsHelper
    def url_to_endpoint(url)
        uri = URI.parse(url)
        endpoint = uri.path.sub(/^\//, '')
        endpoint
    end
    def rest_hostname
        extract_hostname($REST_URL)
    end

    def extract_hostname(url)
        begin
            uri = URI.parse(url)
            uri.hostname
        rescue URI::InvalidURIError
            url
        end
    end

    def link?(str)
        # Regular expression to match strings starting with "http://" or "https://"
        link_pattern = /\Ahttps?:\/\//
        str = str&.strip
        # Check if the string matches the pattern
        !!(str =~ link_pattern)
    end

    def link_last_part(url)
        return "" if url.nil?

        if url.include?('#')
            url.split('#').last
        else
            url.split('/').last
        end
    end

    def escape(string)
        CGI.escape(string) if string
    end

    def unescape(string)
        CGI.unescape(string) if string
    end

    def encode_param(string)
        escape(string)
    end

    # Page a feedback is about. /feedback keeps the page it already reports:
    # wrapping its own URL nests one level per click, an endless crawler trap.
    # e.g. /feedback?location=/ontologies/X must not link to
    #      /feedback?location=/feedback?location=/ontologies/X
    def feedback_location
        return params[:location] if request.path == feedback_path

        encode_param(request.url)
    end
end
