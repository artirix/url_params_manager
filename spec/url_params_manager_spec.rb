require 'spec_helper'

describe UrlParamsManager do
  it 'has a version number' do
    expect(UrlParamsManager::VERSION).not_to be nil
  end

  Given(:url_to_filter_params) {
    {
      # URL => FILTER
      feat: :feature, # indexed => in URL
      cap:  :capacity, # indexed => in URL
      some: :something, # not indexed => in querystring
      ndef: :non_default, # value with default
      page: :page,
    }
  }

  Given(:indexed_url_params_order) {
    [
      :feat,
      :cap,
      :ndef,
      # ALWAYS LAST
      :page
    ]
  }

  Given(:url_helper_method_module) {
    Module.new do
      def self.my_thing_path(params)
        path = "/search/#{params.delete(:filters)}"
        if params.present?
          path << "?#{params.to_query}"
        end
        path
      end
    end
  }

  Given(:default_params) {
    {
      non_default:        99,
      with_default_value: 2,
      with_default_list:  [1, 2],
    }
  }

  Given(:current_app_url_helpers) {
    # Rails.application.routes.url_helpers.tap { |app| app.extend url_helper_method_module }
    url_helper_method_module
  }

  Given(:subject) do
    described_class.for url_to_filter_params:     url_to_filter_params,
                        indexed_url_params_order: indexed_url_params_order,
                        app_url_helpers:          current_app_url_helpers,
                        default_params:           default_params
  end

  describe "url from filters" do
    Given(:filter_params) {
      {
        capacity:           ['25+'],
        page:               2,
        feature:            ['swimming-pool', 'helipad'],
        something:          ['other', 'another'],
        with_default_value: 2,
        with_default_list:  [2, 1],
        non_default:        1,
      }
    }
    Given(:expected_path) {
      indexed_path = [
        'feat-helipad',
        'feat-swimming-pool',
        'cap-25+',
        'ndef-1',
        'page-2'
      ].join('/')

      querystring_part = {
        some: ['another', 'other'],
      }

      "/search/#{indexed_path}?#{querystring_part.to_query}"
    }

    When(:path) { subject.my_thing_path(filter_params) }
    Then { expected_path == '/search/feat-helipad/feat-swimming-pool/cap-25+/ndef-1/page-2?some%5B%5D=another&some%5B%5D=other' }

    Then { URI.parse(path).path == URI.parse(expected_path).path }
    Then do
      expected = CGI.parse(URI.parse(path).query).map { |k, v| [k, v.sort] }
      actual   = CGI.parse(URI.parse(expected_path).query).map { |k, v| [k, v.sort] }
      actual == expected
    end
  end

  describe 'filters from url' do
    context 'real URL' do
      Given(:url_params) {
        {
          filters: 'feat-helipad/feat-swimming-pool/cap-25+/page-2',
          some:    ['another', 'other']
        }
      }

      Given(:expected_filters) {
        default_params.merge feature:   ['helipad', 'swimming-pool'],
                             capacity:  '25+',
                             something: ['another', 'other'],
                             page:      '2'

      }

      When(:filters) { subject.filters_from_url_params(url_params) }
      Then { filters == expected_filters }
    end

    context 'URL with unrecognized indexed param' do
      Given(:url_params) {
        {
          filters: 'feat-helipad/feat-swimming-pool/cap-25+/whoareyou-value/page-2',
          some:    ['another', 'other']
        }
      }

      When(:filters) { subject.filters_from_url_params(url_params) }
      Then { expect(filters).to have_failed(UrlParamsManager::UnrecognisedPrefixError, "url part: whoareyou-value") }
    end
  end

  describe 'with `filter_params_treatment`' do

    Given(:filter_params_treatment) do
      ->(filter_params) do
        if Array(filter_params[:stuff_to_treat]).size > 1
          filter_params[:stuff_to_treat] = 'treated!'
        end

        filter_params
      end
    end

    Given(:subject) do
      described_class.for url_to_filter_params:     url_to_filter_params,
                          indexed_url_params_order: indexed_url_params_order,
                          app_url_helpers:          current_app_url_helpers,
                          default_params:           default_params,
                          filter_params_treatment:  filter_params_treatment
    end

    context 'treatment to be applied' do
      Given(:url_params) {
        {
          filters:        'feat-helipad/feat-swimming-pool/cap-25+/page-2',
          some:           ['another', 'other'],
          stuff_to_treat: ['open', 'closed'],
        }
      }

      Given(:expected_filters) {
        default_params.merge feature:   ['helipad', 'swimming-pool'],
                             capacity:  '25+',
                             something: ['another', 'other'],
                             stuff_to_treat: 'treated!',
                             page:      '2'

      }

      When(:filters) { subject.filters_from_url_params(url_params) }
      Then { filters == expected_filters }
    end

    context 'treatment not to be applied' do
      Given(:url_params) {
        {
          filters:        'feat-helipad/feat-swimming-pool/cap-25+/page-2',
          some:           ['another', 'other'],
          stuff_to_treat: 'open',
        }
      }

      Given(:expected_filters) {
        default_params.merge feature:   ['helipad', 'swimming-pool'],
                             capacity:  '25+',
                             something: ['another', 'other'],
                             stuff_to_treat: 'open',
                             page:      '2'

      }

      When(:filters) { subject.filters_from_url_params(url_params) }
      Then { filters == expected_filters }
    end
  end
end
