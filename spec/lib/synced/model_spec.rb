require "spec_helper"

describe Synced::Model do
  class DummyModel < ActiveRecord::Base
    def self.column_names
      %w(synced_id synced_all_at synced_data)
    end
    synced associations: %i(comments votes)
  end

  describe ".synced_id_key" do
    it "returns key used for storing remote object id" do
      expect(DummyModel.synced_id_key).to eq :synced_id
    end
  end

  describe ".synced_all_at_key" do
    it "returns key used for storing object's synchronization time" do
      expect(DummyModel.synced_all_at_key).to eq :synced_all_at
    end
  end

  describe ".synced_data_key" do
    it "returns key used for storing remote data" do
      expect(DummyModel.synced_data_key).to eq :synced_data
    end
  end

  describe ".synced_associations" do
    it "returns association(s) for which synced is enabled" do
      expect(DummyModel.synced_associations).to eq %i(comments votes)
    end
  end

  describe ".synced" do
    it "makes object synchronizeable" do
      expect(DummyModel).to respond_to(:synchronize)
    end

    it "allows to set custom synced_id_key" do
      klass = dummy_model do
        synced id_key: :remote_id
      end
      expect(klass.synced_id_key).to eq :remote_id
    end

    it "allows to set custom synced_all_at_key" do
      klass = dummy_model do
        synced synced_all_at_key: :remote_updated_at
      end
      expect(klass.synced_all_at_key).to eq :remote_updated_at
    end

    it "allows to set custom synced_data_key" do
      klass = dummy_model do
        synced data_key: :remote_data
      end
      expect(klass.synced_data_key).to eq :remote_data
    end

    context "when data_key set to nil" do
      it "doesn't create reader/writer for synced_data" do
        expect(Photo.new).not_to respond_to(:synced_data)
      end
    end
  end

  it "synchronizes model" do
    expect {
      Rental.synchronize(remote: [remote_object(id: 12,
        updated_at: 2.days.ago)])
    }.to change { Rental.count }.by(1)
  end

  def dummy_model(&block)
    klass = Class.new(ActiveRecord::Base) do
      def self.column_names
        %w(synced_id synced_data synced_all_at)
      end
    end
    klass.instance_eval &block
  end
end
