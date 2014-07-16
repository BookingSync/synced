require "spec_helper"

describe Synced::Engine::Model do
  class DummyModel < ActiveRecord::Base
    synced
  end

  describe ".synced_id_key" do
    it "returns key used for storing remote object id" do
      expect(DummyModel.synced_id_key).to eq :synced_id
    end
  end

  describe ".synced_updated_at_key" do
    it "returns key used for storing remote updated at" do
      expect(DummyModel.synced_updated_at_key).to eq :synced_updated_at
    end
  end

  describe ".synced_data_key" do
    it "returns key used for storing remote data" do
      expect(DummyModel.synced_data_key).to eq :synced_data
    end
  end

  describe ".synced" do
    it "makes object synchronizeable" do
      expect(DummyModel).to respond_to(:synchronize)
    end

    it "allows to set custom synced_id_key" do
      klass = Class.new(ActiveRecord::Base) do
        synced id_key: :remote_id
      end
      expect(klass.synced_id_key).to eq :remote_id
    end

    it "allows to set custom synced_updated_at_key" do
      klass = Class.new(ActiveRecord::Base) do
        synced updated_at_key: :remote_updated_at
      end
      expect(klass.synced_updated_at_key).to eq :remote_updated_at
    end

    it "allows to set custom synced_data_key" do
      klass = Class.new(ActiveRecord::Base) do
        synced data_key: :remote_data
      end
      expect(klass.synced_data_key).to eq :remote_data
    end
  end

  it "synchronizes model" do
    expect {
      Rental.synchronize(remote: [remote_object(id: 12,
        updated_at: 2.days.ago)])
    }.to change { Rental.count }.by(1)
  end
end
