require "spec_helper"

describe Synced::Model do
  class DummyModel < ActiveRecord::Base
    def self.column_names
      %w(synced_id synced_all_at synced_data)
    end
    synced associations: %i(comments votes), remove: true
  end

  describe ".synced_id_key" do
    it "returns key used for storing remote object id" do
      expect(DummyModel.synced_id_key).to eq :synced_id
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

  describe ".synced_remove" do
    it "returns remove setting from declared in the model" do
      expect(DummyModel.synced_remove).to be_truthy
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

    context "on unknown option" do
      it "raises unknown key exception" do
        expect {
          dummy_model { synced i_have_no_memory_of_this_place: true }
        }.to raise_error { |error|
          expect(error.message).to eq "Unknown key: :i_have_no_memory_of_this_place. " \
            + "Valid keys are: :associations, :data_key, :fields, :globalized_attributes, :id_key, " \
            + ":include, :initial_sync_since, :local_attributes, :mapper, :only_updated, :remove, " \
            + ":auto_paginate, :transaction_per_page, :delegate_attributes, :query_params, :timestamp_strategy, " \
            + ":handle_processed_objects_proc, :tolerance"
        }
      end
    end
  end

  describe "#synchronize" do
    it "synchronizes model" do
      expect {
        Rental.synchronize(remote: [remote_object(id: 12,
          updated_at: 2.days.ago)])
      }.to change { Rental.count }.by(1)
    end

    context "on unknown option" do
      it "raises unknown key exception" do
        expect {
          Rental.synchronize(i_have_no_memory_of_this_place: true)
        }.to raise_error { |error|
          expect(error.message).to eq "Unknown key: :i_have_no_memory_of_this_place. " \
            + "Valid keys are: :api, :fields, :include, :remote, :remove, :query_params, :association_sync, :auto_paginate, :transaction_per_page"
        }
      end
    end

    context "auto_paginate" do
      let(:account) { Account.create(name: "test") }
      let(:request_timestamp) { 1.year.ago }

      it "uses auto_paginate from class-level declaration" do
        expect(account.api).to receive(:paginate)
          .with("rentals", { auto_paginate: false }).and_yield([])
        Rental.synchronize(scope: account)
      end

      it "overrides auto_paginate from class-level declaration" do
        expect(account.api).to receive(:paginate)
          .with("rentals", { auto_paginate: true }).and_return([])
        Rental.synchronize(scope: account, auto_paginate: true)
      end
    end

    context "transaction_per_page" do
      let(:account) { Account.create(name: "test") }

      around do |example|
        LosRecord.instance_eval do
          synced strategy: :updated_since,
                 timestamp_strategy: Synced::Strategies::SyncedPerScopeTimestampStrategy,
                 transaction_per_page: true
        end

        LosRecordsSyncSetupHelper.with_multipage_sync_crashing_on_second_page do
          example.run
        end
      end

      it "uses transaction_per_page from class-level declaration" do
        expect {
          begin
            LosRecord.synchronize(scope: account, strategy: :full)
          rescue ActiveRecord::RecordInvalid
          end
        }.to change { LosRecord.count }
      end

      it "overrides transaction_per_page from class-level declaration" do
        expect {
          begin
            LosRecord.synchronize(scope: account, strategy: :full, transaction_per_page: false)
          rescue ActiveRecord::RecordInvalid
          end
        }.not_to change { LosRecord.count }
      end
    end

    context "query_params" do
      let(:request_timestamp) { 1.year.ago }

      it "uses query_params from class-level declaration accepting lambdas with arity 1
      (with argument being :scope) and passes value to api" do
        account = Account.create(name: "test")
        expect(account.api).to receive(:paginate)
          .with("bookings", { auto_paginate: true, from: account.import_bookings_since, updated_since: nil })
          .and_return([])
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        Booking.synchronize(scope: account)
      end

      it "overrides query_params from class-level declaration accepting lambdas with arity 0 and passes value to api" do
        account = Account.create(name: "test")
        from = Time.zone.parse("2010-01-01 12:00:00")
        expect(account.api).to receive(:paginate)
          .with("bookings", { auto_paginate: true, from: from, updated_since: nil })
          .and_return([])
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        Booking.synchronize(scope: account, query_params: { from: -> { from } })
      end

      it "overrides query_params from class-level declaration accepting raw values and passes value to api" do
        account = Account.create(name: "test")
        from = Time.zone.parse("2010-01-01 12:00:00")
        expect(account.api).to receive(:paginate)
          .with("bookings", { auto_paginate: true, from: from, updated_since: nil })
          .and_return([])
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        Booking.synchronize(scope: account, query_params: { from: from })
      end
    end

    context "scope" do
      let(:account) { Account.create(name: "test") }
      let(:strategy) { double(:strategy, perform: true) }

      context "when association is present" do
        it "finds scope from the association" do
          expect(Synced::Synchronizer).to receive(:new).with(anything, hash_including(scope: account)).and_return(strategy)
          account.bookings.synchronize
        end
      end

      context "when explicit scope given" do
        let(:another_account) { Account.create(name: "another") }

        it "overrides the associations one" do
          expect(Synced::Synchronizer).to receive(:new).with(anything, hash_including(scope: another_account)).and_return(strategy)
          account.bookings.synchronize(scope: another_account)
        end

        it "uses the scope given in options" do
          expect(Synced::Synchronizer).to receive(:new).with(anything, hash_including(scope: another_account)).and_return(strategy)
          Booking.synchronize(scope: another_account)
        end
      end

      context "when no scope source available" do
        let(:another_account) { Account.create(name: "another") }

        it "the scope option is not set" do
          expect(Synced::Synchronizer).to receive(:new).with(anything, hash_excluding(scope: another_account)).and_return(strategy)
          Booking.synchronize
        end
      end
    end
  end

  describe ".reset_synced" do
    let(:account) { Account.create }
    let(:request_timestamp) { 1.year.ago }

    context "synced_all_at timestamp strategy (booking model)" do
      let(:remote_bookings) { [remote_object(id: 12), remote_object(id: 15)] }
      before do
        allow(account.api).to receive(:paginate).with("bookings",
          { updated_since: nil, auto_paginate: true })
          .and_return(remote_bookings)
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        Booking.synchronize(scope: account, query_params: {})
      end

      it "resets synced_all_at column" do
        expect {
         Booking.reset_synced
        }.to change { Booking.all.map(&:synced_all_at) }.to [nil, nil]
      end

      context "invoked on relation" do
        it "resets synced_all_at within given relation" do
          booking = Booking.create(synced_all_at: 2.days.ago)
          expect {
            expect {
              account.bookings.reset_synced(scope: account)
            }.to change { account.bookings.reload.map(&:synced_all_at) }.to [nil, nil]
          }.not_to change { booking.reload.synced_all_at }
        end
      end

      context "on model without synced_all_at column" do
        it "doesn't try to update the column" do
          expect(Location).to receive(:update_all).never
          Location.reset_synced
        end
      end
    end

    context "synced_per_scope timestamp strategy (los record model)" do
      context "global reset" do
        it "destroys all synced_timestamps records for LosRecord model, with and without scope" do
          Synced::Timestamp.create(synced_at: Time.now, model_class: "LosRecord",
            parent_scope_id: account.id, parent_scope_type: "Account")
          expect {
            LosRecord.reset_synced
          }.to change(Synced::Timestamp, :count).by(-1)
        end
      end

      context "scoped per account reset" do
        let(:other_account) { Account.create }

        it "destroys all synced_timestamps records for LosRecord model, with and without scope" do
          timestamp_for_account = Synced::Timestamp.create(synced_at: Time.now,
            model_class: "LosRecord",
            parent_scope_id: account.id,
            parent_scope_type: "Account"
          )
          timestamp_for_other_account = Synced::Timestamp.create(synced_at: Time.now,
            model_class: "LosRecord",
            parent_scope_id: other_account.id,
            parent_scope_type: "Account"
          )
          expect {
            account.los_records.reset_synced
          }.to change(Synced::Timestamp, :count).by(-1)
          expect {
            timestamp_for_account.reload
          }.to raise_error ActiveRecord::RecordNotFound
          expect {
            timestamp_for_other_account.reload
          }.not_to raise_error
        end
      end
    end
  end

  def dummy_model(dummy_columns = nil, &block)
    @dummy_columns = dummy_columns
    klass = Class.new(ActiveRecord::Base) do
      def self.column_names
        @dummy_columns || %w(synced_id synced_data synced_all_at)
      end
    end
    klass.instance_eval &block
  end
end
