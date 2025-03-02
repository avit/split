require 'spec_helper'
require 'split/experiment_catalog'
require 'split/experiment'
require 'split/user'

describe Split::User do
  let(:user_keys) { { 'link_color' => 'blue' } }
  let(:context) { double(:session => { split:  user_keys }) }
  let(:experiment) { Split::Experiment.new('link_color') }

  before(:each) do
    @subject = described_class.new(context)
  end

  it 'delegates methods correctly' do
    expect(@subject['link_color']).to eq(@subject.user['link_color'])
  end

  context '#cleanup_old_versions!' do
    let(:experiment_version) { "#{experiment.name}:1" }
    let(:second_experiment_version) { "#{experiment.name}_another:1" }
    let(:third_experiment_version) { "variation_of_#{experiment.name}:1" }
    let(:user_keys) do
      {
        experiment_version => 'blue',
        second_experiment_version => 'red',
        third_experiment_version => 'yellow'
      }
    end

    before(:each) { @subject.cleanup_old_versions!(experiment) }

    it 'removes key if old experiment is found' do
      expect(@subject.keys).not_to include(experiment_version)
    end

    it 'does not remove other keys' do
      expect(@subject.keys).to include(second_experiment_version, third_experiment_version)
    end
  end 

  context '#cleanup_old_experiments!' do
    it 'removes key if experiment is not found' do
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to be_empty
    end

    it 'removes key if experiment has a winner' do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:start_time).and_return(Date.today)
      allow(experiment).to receive(:has_winner?).and_return(true)
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to be_empty
    end

    it 'removes key if experiment has not started yet' do
      allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
      allow(experiment).to receive(:has_winner?).and_return(false)
      @subject.cleanup_old_experiments!
      expect(@subject.keys).to be_empty
    end

    context 'with finished key' do
      let(:user_keys) { { 'link_color' => 'blue', 'link_color:finished' => true } }

      it 'does not remove finished key for experiment without a winner' do
        allow(Split::ExperimentCatalog).to receive(:find).with('link_color').and_return(experiment)
        allow(Split::ExperimentCatalog).to receive(:find).with('link_color:finished').and_return(nil)
        allow(experiment).to receive(:start_time).and_return(Date.today)
        allow(experiment).to receive(:has_winner?).and_return(false)
        @subject.cleanup_old_experiments!
        expect(@subject.keys).to include("link_color")
        expect(@subject.keys).to include("link_color:finished")
      end
    end

    context 'when already cleaned up' do
      before do
        @subject.cleanup_old_experiments!
      end

      it 'does not clean up again' do
        expect(@subject).to_not receive(:keys_without_finished)
        @subject.cleanup_old_experiments!
      end
    end
  end

  context 'allows user to be loaded from adapter' do
    it 'loads user from adapter (RedisAdapter)' do
      user = Split::Persistence::RedisAdapter.new(nil, 112233)
      user['foo'] = 'bar'

      ab_user = Split::User.find(112233, :redis)

      expect(ab_user['foo']).to eql('bar')
    end

    it 'returns nil if adapter does not implement a finder method' do
      ab_user = Split::User.find(112233, :dual_adapter)
      expect(ab_user).to be_nil
    end

  end

  context "instantiated with custom adapter" do
    let(:custom_adapter) { double(:persistence_adapter) }

    before do
      @subject = described_class.new(context, custom_adapter)
    end

    it "sets user to the custom adapter" do
      expect(@subject.user).to eq(custom_adapter)
    end
  end

end
