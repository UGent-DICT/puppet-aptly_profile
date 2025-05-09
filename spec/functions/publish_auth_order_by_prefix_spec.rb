require 'spec_helper'

describe 'aptly_profile::publish_auth_order_by_prefix' do
  let(:repos) do
    {
      'repo1' => { 'allow_from' => ['deployuser'] },
      'repo2' => { 'allow_from' => 'authenticated' },
    }
  end

  describe 'splits by prefix' do
    let(:publish) do
      {
        'foobar' => {},
        'main/foo' => {
          'paramx' => 'foobar',
        },
        'main/bar' => {
          'allow_from' => ['user1'],
        },
      }
    end

    let(:expected_result) do
      {
        '' => {
          'foobar' => {
            'api' => nil,
            'public' => nil,
          },
        },
        'main' => {
          'foo' => {
            'api' => nil,
            'public' => nil,
          },
          'bar' => {
            'api' => nil,
            'public' => ['user1'],
          },
        },
      }
    end

    it do
      is_expected.to run.with_params(publish, repos).and_return(expected_result)
    end
  end

  describe 'validates allow_from values' do
    let(:publish) do
      {
        'main' => { 'allow_from' => 'wrong_value' },
      }
    end

    it do
      is_expected.to run.with_params(publish, repos).and_raise_error(%r{'allow_from' for publish point 'main' expects a })
    end
  end

  describe 'sanitizes allow_from parameters' do
    let(:publish) do
      {
        'not_defined' => { 'param1' => 'value1' },
        'wrong_defined' => { 'allow_from' => :undef },
        'specified' => { 'allow_from' => ['user1'] },
      }
    end
    let(:expected_result) do
      {
        '' => {
          'not_defined' => {
            'api' => nil,
            'public' => nil,
          },
          'wrong_defined' => {
            'api' => nil,
            'public' => nil,
          },
          'specified' => {
            'api' => nil,
            'public' => ['user1'],
          },
        },
      }
    end

    it do
      is_expected.to run.with_params(publish, repos).and_return(expected_result)
    end
  end

  describe 'sorts' do
    let(:publish) do
      {
        'jjj' => { 'allow_from' => ['user'] },
        'z/b' => {},
        'z/a' => {},
        'a/b' => { 'allow_from' => ['user'] },
        'zzz' => { 'allow_from' => ['bbb', 'ooo', 'aaa', 'ttt'] },
        'aaa' => {},
      }
    end

    it do
      is_expected.to run.with_params(publish, repos).and_return(
        '' => {
          'aaa' => {
            'api' => nil,
            'public' => nil,
          },
          'jjj' => {
            'api' => nil,
            'public' => ['user'],
          },
          'zzz' => {
            'api' => nil,
            'public' => ['aaa', 'bbb', 'ooo', 'ttt'],
          },
        },
        'a' => {
          'b' => {
            'api' => nil,
            'public' => ['user'],
          },
        },
        'z' => {
          'a' => {
            'api' => nil,
            'public' => nil,
          },
          'b' => {
            'api' => nil,
            'public' => nil,
          },
        },
      )
    end
  end
end
