require 'spec_helper'

describe 'aptly_profile::publish_auth_clean_and_default_prefixes' do
  let(:data) { {} }
  let(:default) { 'default_allow_from' }
  let(:prefixes) do
    {
      'bis' => 'default_from_prefixes',
    }
  end

  it do
    is_expected.not_to eq(nil)
  end

  it do
    is_expected.to run.with_params(default, {}, {}).and_return({})
  end

  it do
    is_expected.to run.with_params(
      default, {
        'full_empty' => {
          'foo' => {
            'api' => nil,
            'public' => nil,
          },
          'bar' => {
            'api' => nil,
            'public' => nil,
          },
        },
      }, {}
    ).and_return({})
  end

  it do
    is_expected.to run.with_params(
      default, {
        '' => {
          'with_api' => {
            'api' => ['userx'],
            'public' => nil,
          },
        },
      }, {}
    ).and_return(
      '' => {
        'with_api' => {
          'api' => ['userx'],
        },
      },
    )
  end

  it do
    is_expected.to run.with_params(
      default,
      {
        '' => {
          'main' => {
            'api' => nil,
            'public' => ['user1'],
          },
          'unknown' => {
            'api' => nil,
            'public' => nil,
          },
        },
        'bis' => {
          'main' => {
            'api' => nil,
            'public' => 'prefix',
          },
          'unknown' => {
            'api' => nil,
            'public' => nil,
          },
        },
        'nowork' => {
          'foo' => {
            'api' => nil,
            'public' => ['user1'],
          },
          'bar' => {
            'api' => nil,
            'public' => ['user2'],
          },
        },
        'empty' => {
          'nope' => {
            'api' => nil,
            'public' => nil,
          },
          'also_nope' => {
            'api' => nil,
            'public' => nil,
          },
        },
      },
      prefixes,
    ).and_return(
      '' => {
        'main' => { 'public' => ['user1'] },
        'unknown' => { 'public' => 'default_allow_from' },
      },
      'bis' => {
        'main' => { 'public' => 'prefix' },
        'unknown' => { 'public' => 'default_from_prefixes' },
      },
      'nowork' => {
        'foo' => { 'public' => ['user1'] },
        'bar' => { 'public' => ['user2'] },
      },
    )
  end
end
