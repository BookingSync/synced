require "spec_helper"

describe Synced::Synchronizer do
  let(:account) { Account.create }
  let(:model_class) { Amenity }

  context "when :remote not given" do
    it "uses given :full strategy" do
      synchronizer = Synced::Synchronizer.new(model_class, strategy: :full)
      expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
    end

    it "uses given :updated_since strategy" do
      synchronizer = Synced::Synchronizer.new(model_class, strategy: :updated_since)
      expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::UpdatedSince)
    end

    it "uses given :check strategy" do
      synchronizer = Synced::Synchronizer.new(model_class, strategy: :check)
      expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Check)
    end
  end

  context "when remote present" do
    it "uses :full despite given :updated_since strategy" do
      synchronizer = Synced::Synchronizer.new(model_class, strategy: :updated_since, remote: [])
      expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
    end

    it "uses :full despite given :check strategy" do
      synchronizer = Synced::Synchronizer.new(model_class, strategy: :check, remote: [])
      expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
    end
  end
end
