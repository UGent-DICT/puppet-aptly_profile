require 'spec_helper'

describe 'aptly_profile::publish_auth_order_by_prefix' do
  describe 'splits by prefix' do
    let(:publish) do
      {
        'foobar' => {},
        'main/foo' => {},
        'main/bar' => {
          'allow_from' => ['user1'],
        },
      }
    end

    let(:expected_result) do
      {
        '' => {
          'foobar' => nil,
        },
        'main' => {
          'foo' => nil,
          'bar' => ['user1'],
        },
      }
    end

    it do
      is_expected.to run.with_params(publish).and_return(expected_result)
    end
  end

  describe 'cleans up unwanted parameters' do
    let(:publish) do
      {
        'foobar' => {},
        'main/foo' => {
          'param1' => 'value1',
          'param2' => 'value2',
        },
        'main/bar' => {
          'allow_from' => ['user1'],
          'param3' => 'value3',
        },
      }
    end
    let(:expected_result) do
      {
        '' => {
          'foobar' => nil,
        },
        'main' => {
          'foo' => nil,
          'bar' => ['user1'],
        },
      }
    end

    it do
      is_expected.to run.with_params(publish).and_return(expected_result)
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
          'not_defined' => nil,
          'wrong_defined' => nil,
          'specified' => ['user1'],
        },
      }
    end

    it do
      is_expected.to run.with_params(publish).and_return(expected_result)
    end
  end

  describe 'validates allow_from values' do
    let(:publish) do
      {
        'main' => { 'allow_from' => 'wrong_value' },
      }
    end

    it do
      is_expected.to run.with_params(publish).and_raise_error(%r{'allow_from' for publish point 'main' expects a })
    end
  end

  describe 'sorts' do
    let(:publish) do
      {
        'jjj' => { 'allow_from' => ['user'] },
        'z/b' => {},
        'z/a' => {},
        'a/b' => { 'allow_from' => ['user'] },
        'zzz' => {},
        'aaa' => {},
      }
    end

    it do
      is_expected.to run.with_params(publish).and_return(
        '' => {
          'aaa' => nil,
          'jjj' => ['user'],
          'zzz' => nil,
        },
        'a' => {
          'b' => ['user'],
        },
        'z' => {
          'a' => nil,
          'b' => nil,
        },
      )
    end
  end
end
