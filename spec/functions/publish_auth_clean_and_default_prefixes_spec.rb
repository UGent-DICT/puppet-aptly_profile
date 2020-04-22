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
        'full_empty' => { 'foo' => nil, 'bar' => nil },
      }, {}
    ).and_return({})
  end

  it do
    is_expected.to run.with_params(
      default,
      {
        '' => {
          'main' => ['user1'],
          'unknown' => nil,
        },
        'bis' => {
          'main' => 'prefix',
          'unknown' => nil,
        },
        'nowork' => {
          'foo' => ['user1'],
          'bar' => ['user2'],
        },
        'empty' => {
          'nope' => nil,
          'also_nope' => nil,
        },
      },
      prefixes,
    ).and_return(
      '' => {
        'main' => ['user1'],
        'unknown' => 'default_allow_from',
      },
      'bis' => {
        'main' => 'prefix',
        'unknown' => 'default_from_prefixes',
      },
      'nowork' => {
        'foo' => ['user1'],
        'bar' => ['user2'],
      },
    )
  end
end
