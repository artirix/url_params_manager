require 'active_support/all'
require 'url_params_manager/unrecognised_prefix_error'
require 'url_params_manager/service'
require 'url_params_manager/version'

module UrlParamsManager
  def self.for(url_to_filter_params: nil,
    indexed_url_params_order: nil,
    app_url_helpers: nil,
    default_params: {},
    always_lists_fields: {},
    position_defined_url_params: nil,
    filter_params_treatment: ->(filter_params) { filter_params }
  )
    Service.new url_to_filter_params:        url_to_filter_params,
                indexed_url_params_order:    indexed_url_params_order,
                app_url_helpers:             app_url_helpers,
                default_params:              default_params,
                filter_params_treatment:     filter_params_treatment,
                position_defined_url_params: position_defined_url_params,
                always_lists_fields:         always_lists_fields

  end
end
