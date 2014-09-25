module LinkHelper
  def link_header(path, count, page, per_page)
    total_pages = (count / per_page.to_f).ceil
    links = {}
    links[:first] = url_for(path)
    links[:prev] = url_for(path, page: page - 1, per_page: per_page) if page > 1
    links[:next] = url_for(path, page: page + 1, per_page: per_page) if page < total_pages
    links[:last] = url_for(path, page: total_pages, per_page: per_page)
    if links.empty?
      nil
    else
      { 'Link' => links.map { |rel, url| "<#{url}>; rel=\"#{rel}\"" }.join(',') }
    end
  end

  def url_for(path, options = {})
    if (request.scheme == 'http' && request.port == 80) ||
       (request.scheme == 'https' && request.port == 443)
      port = ''
    else
      port = ":#{request.port}"
    end
    url = "#{request.scheme}://#{request.host}#{port}#{request.script_name}#{path}"
    url += '?' + options.map { |key, value| "#{key}=#{value}" }.join('&') unless options.empty?
    url
  end
end
