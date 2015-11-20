module UrlParamsManager
  class Service
    EMPTY_STRING                            = ''.freeze
    PREFIX_SEPARATOR                        = '-'.freeze
    DEFAULT_PLACEHOLDER                     = '_'.freeze
    DEFAULT_MULTIPLE_SEPARATOR_FOR_POSITION = '--'.freeze
    DEFAULT_FILTER_PARAMS_TREATMENT         = ->(filter_params) { filter_params }

    attr_reader :app_url_helpers,
                :url_to_filter_params,
                :indexed_url_params_order,
                :filter_to_url_params,
                :default_params,
                :position_defined_url_params,
                :filter_params_treatment,
                :always_lists_fields

    def initialize(url_to_filter_params: nil,
                   indexed_url_params_order: nil,
                   app_url_helpers: nil,
                   default_params: {},
                   always_lists_fields: {},
                   position_defined_url_params: nil,
                   filter_params_treatment: DEFAULT_FILTER_PARAMS_TREATMENT
    )
      @url_to_filter_params        = url_to_filter_params
      @filter_to_url_params        = url_to_filter_params.invert
      @indexed_url_params_order    = indexed_url_params_order.map &:to_s
      @app_url_helpers             = app_url_helpers
      @default_params              = default_params
      @position_defined_url_params = position_defined_url_params.presence || {}
      @filter_params_treatment     = filter_params_treatment
      @always_lists_fields         = prepare_always_lists_fields(always_lists_fields)
    end

    # for url/path methods from filter args
    def method_missing(method, args)
      path_method method, args
    end

    # for filters from url/path params
    def filters_from_url_params(params)
      params = params.to_h.symbolize_keys

      filters = unfold_filters(params)

      pars = filters.merge querystring_to_filters(params)

      filter_params(pars)
    end

    def querystring_to_filters(querystring_params)
      querystring_params.inject({}) do |h, (k, v)|
        new_key    = url_to_filter_params[k] || k
        h[new_key] = v
        h
      end
    end

    private

    #################
    # FILTER -> URL #
    #################

    def path_method(method, filter_args)
      url_args = url_args_from_filters(filter_args)
      app_url_helpers.send(method, url_args)
    end


    def url_args_from_filters(filter_args)
      filter_pars       = filter_params(filter_args)
      valid_filter_args = remove_defaults(filter_pars)

      bare_args = translate_filter_keys(valid_filter_args)

      in_uri_args       = bare_args.select { |(url_param, _)| url_param_in_path?(url_param) }
      query_string_args = bare_args.reject { |(url_param, _)| url_param_in_path?(url_param) }

      # adding placeholders
      with_placeholders = add_placeholders in_uri_args

      # sorting indexed part
      sorted_uri_args   = sort_uri_filters with_placeholders

      # converting into string
      filters_uri_part  = generate_uri_part sorted_uri_args

      # query string args + filter param for the urlpath helper methods
      query_string_args.merge filters: filters_uri_part.join('/')
    end

    def add_placeholders(sorted_uri_args)
      position_based_keys = position_defined_url_params.keys.reverse
      need_placeholder    = false

      position_based_keys.inject(sorted_uri_args) do |args, key|
        options          = position_defined_url_params[key] || {}
        need_placeholder = need_placeholder || args[key].present?

        if need_placeholder && args[key].blank?
          args[key] = options[:placeholder] || DEFAULT_PLACEHOLDER
        end

        args
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

    def url_param_in_path?(url_param)
      indexed_url_params_order.include?(url_param.to_s) || position_defined_url_params.key?(url_param)
    end

    def sort_uri_filters(in_uri_args)
      position_uri_args = in_uri_args.select { |k, _| position_defined_url_params.key? k }
      prefix_uri_args   = in_uri_args.reject { |k, _| position_defined_url_params.key? k }

      final_list = []

      final_list = final_list.concat sort_uri_filters_by_position(position_uri_args)
      final_list = final_list.concat sort_uri_filters_by_prefix(prefix_uri_args)

      final_list.map do |k, v|
        sorted_v = v.respond_to?(:sort) ? v.sort : v
        [k, sorted_v]
      end.to_h
    end

    def sort_uri_filters_by_position(position_uri_args)
      position_keys = position_defined_url_params.keys
      position_uri_args.to_a.sort_by do |k, _|
        position_keys.index(k)
      end
    end

    def sort_uri_filters_by_prefix(prefix_uri_args)
      prefix_uri_args.to_a.sort_by do |k, _|
        indexed_url_params_order.index(k.to_s)
      end
    end

    def generate_uri_part(in_uri_args)
      position_uri_args = in_uri_args.select { |k, _| position_defined_url_params.key? k }
      prefix_uri_args   = in_uri_args.reject { |k, _| position_defined_url_params.key? k }

      generate_uri_parts_by_position(position_uri_args).concat generate_uri_parts_by_prefix(prefix_uri_args)
    end

    def generate_uri_parts_by_position(position_uri_args)
      position_uri_args.inject([]) do |uri, (key, value)|
        options = position_defined_url_params[key]

        prefix     = options[:prefix].present? ? "#{options[:prefix]}-" : EMPTY_STRING
        uri_values = []
        Array(value).each do |v|
          uri_values << "#{prefix}#{v}"
        end

        separator = get_separator_from_position_options(options)
        uri << uri_values.join(separator)

        uri
      end
    end

    def generate_uri_parts_by_prefix(prefix_uri_args)
      prefix_uri_args.inject([]) do |uri, (key, value)|
        Array(value).each do |v|
          uri << "#{key}-#{v}"
        end
        uri
      end
    end


    #################
    # URL -> FILTER #
    #################


    def unfold_filters(params)
      filters = {}.merge default_params

      raw = params.delete(:filters).to_s.split('/')

      used_positions = unfold_filters_by_position(filters, raw)
      unfold_filters_by_prefix(filters, raw.drop(used_positions))

      filters
    end

    def unfold_filters_by_position(filters, raw)

      # the moment we recognise one param with a prefix based, we assume that the position based have stopped
      prefix_based_recognised = false
      position_defined_raw    = raw.inject([]) do |list, url_part|
        prefix_based_recognised ||= recognised_prefix? url_part
        list << url_part unless prefix_based_recognised
        list
      end

      available_position_params = position_defined_url_params.to_a.take(position_defined_raw.size)
      used_positions            = 0

      available_position_params.each_with_index do |(key, options), index|
        used_positions += 1
        value          = raw[index]

        next if value == options[:placeholder]

        separator = get_separator_from_position_options(options)
        values    = value.split(separator)

        filters[key] = values.size > 1 ? values : values.first
      end

      used_positions
    end

    def unfold_filters_by_prefix(filters, raw)
      raw.each do |part|
        filter, value = recognise_prefix(part)
        if filters.has_key? filter
          filters[filter] = Array(filters[filter])
          filters[filter] << value
        else
          filters[filter] = value
        end
      end
    end

    def recognised_prefix?(url_part)
      recognise_prefix(url_part, raise_if_unrecognised: false).present?
    end

    def recognise_prefix(url_part, raise_if_unrecognised: true)
      url_to_filter_params.each do |url_prefix, filter|
        pref = "#{url_prefix}#{PREFIX_SEPARATOR}"
        if url_part.start_with? pref
          return [filter, url_part.sub(pref, EMPTY_STRING)]
        end
      end

      # check if it's the same prefix -> if it is in the indexed parts
      url_part_divided = url_part.split(PREFIX_SEPARATOR)
      param            = url_part_divided.first
      if indexed_url_params_order.include?(param.to_s)
        return [param.to_sym, url_part_divided.drop(1).join(PREFIX_SEPARATOR)]
      end

      if raise_if_unrecognised
        raise UnrecognisedPrefixError, "url part: #{url_part}"
      else
        nil
      end
    end


    ##########
    # COMMON #
    ##########

    def get_separator_from_position_options(options)
      options[:multiple_separator].presence || DEFAULT_MULTIPLE_SEPARATOR_FOR_POSITION
    end

    def filter_params(filter_args)
      filter_args = filter_args.deep_dup
      convert_to_lists(filter_args)
      filter_params_treatment.call filter_args
    end

    def convert_to_lists(filter_args)
      always_lists_fields.each do |field, config|
        if filter_args.key? field
          case config
          when String, Regexp
            filter_args[field] = filter_args[field].to_s.split(config)
          else
            filter_args[field] = Array(filter_args[field])
          end
        end
      end
    end

    def prepare_always_lists_fields(given)
      case given
      when Array
        given.map { |a| [a, true] }.to_h
      when Hash
        given
      else
        { given.to_sym => true }
      end
    end

  end
end