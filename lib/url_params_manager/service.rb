module UrlParamsManager
  class Service
    attr_reader :app_url_helpers,
                :url_to_filter_params,
                :indexed_url_params_order,
                :filter_to_url_params,
                :default_params,
                :filter_params_treatment

    def initialize(url_to_filter_params: nil,
                   indexed_url_params_order: nil,
                   app_url_helpers: nil,
                   default_params: {},
                   filter_params_treatment: ->(filter_params) { filter_params }
    )
      @url_to_filter_params     = url_to_filter_params
      @filter_to_url_params     = url_to_filter_params.invert
      @indexed_url_params_order = indexed_url_params_order
      @app_url_helpers          = app_url_helpers
      @default_params           = default_params
      @filter_params_treatment  = filter_params_treatment
    end

    # for url/path methods from filter args
    def method_missing(method, args)
      path_method method, args
    end

    # for filters from url/path params
    def filters_from_url_params(params)
      params = params.to_h.symbolize_keys

      filters = {}.merge default_params

      params.delete(:filters).to_s.split('/').each do |part|
        filter, value = recognise_prefix(part)
        if filters.has_key? filter
          filters[filter] = Array(filters[filter])
          filters[filter] << value
        else
          filters[filter] = value
        end
      end

      pars = filters.merge querystring_to_filters(params)

      filter_params_treatment.call pars
    end

    def querystring_to_filters(querystring_params)
      querystring_params.inject({}) do |h, (k, v)|
        new_key    = url_to_filter_params[k] || k
        h[new_key] = v
        h
      end
    end

    private
    def path_method(method, filter_args)
      url_args = url_args_from_filters(filter_args)
      app_url_helpers.send(method, url_args)
    end

    EMPTY_STRING = ''.freeze

    def recognise_prefix(url_part)
      url_to_filter_params.each do |url_prefix, filter|
        pref = "#{url_prefix}-"
        if url_part.start_with? pref
          return [filter, url_part.sub(pref, EMPTY_STRING)]
        end
      end

      raise UnrecognisedPrefixError, "url part: #{url_part}"
    end

    def url_args_from_filters(filter_args)
      filter_pars       = filter_params_treatment.call filter_args
      valid_filter_args = remove_defaults(filter_pars)
      bare_args         = translate_filter_keys(valid_filter_args)

      in_uri_args       = bare_args.select { |(k, _)| indexed_url_params_order.include? k }
      query_string_args = bare_args.reject { |(k, _)| indexed_url_params_order.include? k }

      # sorting indexed part
      sorted_uri_args   = sort_uri_filters(in_uri_args)

      #converting into string
      filters_uri_part  = generate_uri_part(sorted_uri_args)

      # query string args + filter param for the urlpath helper methods
      query_string_args.merge filters: filters_uri_part.join('/')
    end

    def sort_uri_filters(in_uri_args)
      keys_sorted = Hash[
        in_uri_args.to_a.sort_by do |k, _|
          @indexed_url_params_order.index(k)
        end
      ]

      Hash[
        keys_sorted.map do |k, v|
          sorted_v = v.respond_to?(:sort) ? v.sort : v
          [k, sorted_v]
        end
      ]

    end

    def translate_filter_keys(filter_args)
      Hash[
        filter_args.map do |k, v|
          [
            filter_to_url_params[k] || k, # new key -> translated one, or the original if no translation available
            v
          ]
        end
      ]
    end

    def generate_uri_part(in_uri_args)
      in_uri_args.inject([]) do |uri, (key, value)|
        Array(value).each do |v|
          uri << "#{key}-#{v}"
        end
        uri
      end
    end

    def remove_defaults(filter_args)
      default_params.each do |k, v|
        next unless filter_args.key?(k) && filter_args[k].present?
        if filter_args[k] == v || Array(filter_args[k]).sort == Array(v).sort
          filter_args.delete k
        end
      end

      filter_args
    end
  end
end