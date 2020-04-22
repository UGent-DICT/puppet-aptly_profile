require 'spec_helper'

describe 'aptly_profile::auth' do
  let(:params) do
    {
      config_path: '/srv/aptly.info/conf.d/aptly_auth.conf',
      enable_api: false,
      owner: 'apache',
      group: 'apache',
    }
  end

  ## Since we override owner,group and enable_api, we should not need this.
  # let(:pre_condition) do
  #   [
  #     "include aptly_profile"
  #   ].join("\n")
  # end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      describe 'default' do
        it do
          is_expected.to compile
        end
      end

      describe 'api_enabled: true' do
        let(:params) { super().merge(enable_api: true) }

        it do
          is_expected.to compile
        end
      end
    end
  end
end
