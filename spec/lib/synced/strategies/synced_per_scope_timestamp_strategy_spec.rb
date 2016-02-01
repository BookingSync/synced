require "spec_helper"

describe Synced::Strategies::SyncedPerScopeTimestampStrategy do
  let(:unrelated_account) { Account.create }
  let(:account) { Account.create }
  let(:timestamp_strategy) { Synced::Strategies::SyncedPerScopeTimestampStrategy.new(scope: account, model_class: Booking) }
  let(:unrelated_scope_timestamp_strategy) { Synced::Strategies::SyncedPerScopeTimestampStrategy.new(scope: unrelated_account, model_class: Booking) }
  let(:unrelated_model_timestamp_strategy) { Synced::Strategies::SyncedPerScopeTimestampStrategy.new(scope: account, model_class: Rental) }

  describe "#last_synced_at" do
    around { |example| Timecop.freeze(Time.zone.now.round) { example.run} }

    before do
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: Time.zone.now)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.day.ago)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.hour.from_now)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.hour.ago)
      # having different model
      Synced::Timestamp.with_scope_and_model(account, Rental).create(synced_at: 2.day.from_now)
      # having different scope
      Synced::Timestamp.with_scope_and_model(unrelated_account, Booking).create(synced_at: 1.day.from_now)
    end

    it "always returns latest synced_at for given scope" do
      expect(timestamp_strategy.last_synced_at).to eq(1.hour.from_now)
      expect(unrelated_scope_timestamp_strategy.last_synced_at).to eq(1.day.from_now)
      expect(unrelated_model_timestamp_strategy.last_synced_at).to eq(2.day.from_now)
    end
  end

  describe "#reset_synced" do
    around { |example| Timecop.freeze(Time.zone.now.round) { example.run} }

    before do
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: Time.zone.now)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.day.ago)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.hour.from_now)
      Synced::Timestamp.with_scope_and_model(account, Booking).create(synced_at: 1.hour.ago)
      # having different model
      Synced::Timestamp.with_scope_and_model(account, Rental).create(synced_at: 2.day.from_now)
      # having different scope
      Synced::Timestamp.with_scope_and_model(unrelated_account, Booking).create(synced_at: 1.day.from_now)
    end

    it "removes timestamps for given scope" do
      expect { timestamp_strategy.reset }.to change(Synced::Timestamp, :count).by(-4)
      expect(Synced::Timestamp.with_scope_and_model(unrelated_account, Booking).count).to eq(1)
      expect(Synced::Timestamp.with_scope_and_model(account, Rental).count).to eq(1)
    end
  end

  describe "#update" do
    around { |example| Timecop.freeze(Time.zone.now.round) { example.run} }

    before do
      Synced::Timestamp.create(parent_scope: unrelated_account, model_class: Booking, synced_at: 1.day.from_now)
    end

    it "properly updates last_synced_at" do
      expect(timestamp_strategy.last_synced_at).to be_nil
      expect {
        timestamp_strategy.update(Time.zone.now)
      }.to change(timestamp_strategy, :last_synced_at).from(nil).to(Time.zone.now)
      expect {
        unrelated_scope_timestamp_strategy.update(1.day.from_now)
      }.not_to change(timestamp_strategy, :last_synced_at)
      expect {
        unrelated_model_timestamp_strategy.update(1.day.from_now)
      }.not_to change(timestamp_strategy, :last_synced_at)
      expect {
        timestamp_strategy.update(1.day.ago)
      }.not_to change(timestamp_strategy, :last_synced_at)
      expect {
        timestamp_strategy.update(1.day.from_now)
      }.to change(timestamp_strategy, :last_synced_at).from(Time.zone.now).to(1.day.from_now)
    end
  end
end
