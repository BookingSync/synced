require "spec_helper"

describe Synced::Synchronizer do
  let(:account) { Account.create }

  describe "#perform" do
    context "for model without only_updated" do
      it "chooses :full strategy" do
        synchronizer = Synced::Synchronizer.new(Class, {})
        expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
      end
    end

    context "for model without synced_all_at_key missing in the db" do
      it "chooses :full strategy" do
        synchronizer = Synced::Synchronizer.new(Class, {})
        expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
      end
    end

    context "for model with only_updated and synced_all_at_key present in the db" do
      it "chooses :updated_since strategy" do
        synchronizer = Synced::Synchronizer.new(Class, only_updated: true,
          synced_all_at_key: :synced_all_at)
        expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::UpdatedSince)
      end
    end

    context "for model with only_updated, synced_all_at_key and remote objects given" do
      it "chooses :full strategy" do
        synchronizer = Synced::Synchronizer.new(Class, only_updated: true,
          synced_all_at_key: :synced_all_at, remote: [{}, {}])
        expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Full)
      end
    end

    context "for model with forced :check strategy" do
      it "chooses :check strategy" do
        synchronizer = Synced::Synchronizer.new(Class, only_updated: true,
          synced_all_at_key: :synced_all_at, strategy: :check)
        expect(synchronizer.strategy).to be_an_instance_of(Synced::Strategies::Check)
      end
    end
  end
end
