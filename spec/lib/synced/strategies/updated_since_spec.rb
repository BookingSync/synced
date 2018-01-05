require "spec_helper"

describe Synced::Strategies::UpdatedSince do
  let(:account) { Account.create(name: "test") }

  describe "#perform" do
    context "with remove: true option" do
      let(:request_timestamp) { 1.year.ago }

      context "deleted_ids are not present in metadata" do
        let(:remote_objects) { [remote_object(id: 12, name: "test-12")] }
        let(:account) { Account.create }
        let!(:booking) { account.bookings.create(synced_id: 10, name: "test-10") }

        before do
          allow(account.api).to receive(:paginate).with("bookings",
            { auto_paginate: true, updated_since: nil }).and_return(remote_objects)
          expect(account.api).to receive(:last_response)
            .and_return(double({ meta: { } })).twice
          expect(account.api).to receive(:pagination_first_response)
            .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        end

        it "raises CannotDeleteDueToNoDeletedIdsError" do
          expect {
            Booking.synchronize(scope: account, remove: true, query_params: {})
          }.to raise_error(Synced::Strategies::UpdatedSince::CannotDeleteDueToNoDeletedIdsError) { |ex|
            msg = "Cannot delete Bookings. No deleted_ids were returned in API response."
            expect(ex.message).to eq msg
          }
        end
      end

      context "and credentials flow" do
        let!(:booking) { Booking.create(synced_id: 2, synced_all_at: "2010-01-01 12:12:12") }

        before do
          expect_any_instance_of(BookingSync::API::Client).to receive(:paginate).and_call_original
          expect_any_instance_of(BookingSync::API::Client).to receive(:last_response).twice.and_call_original
          stub_request(:get, "https://www.bookingsync.com/api/v3/bookings?updated_since=2010-01-01%2012:12:12%20UTC").
                      to_return(:status => 200, body: {"bookings"=>[{"short_name"=>"one", "id"=>1, "account_id"=>1, "rental_id"=>2, "start_at"=>"2014-04-28T10:55:13Z", "end_at"=>"2014-12-28T10:55:34Z"}], "meta"=>{"deleted_ids"=>[2, 17]}}.to_json, :headers => { "x-updated-since-request-synced-at" => request_timestamp.to_s })
        end

        it "looks for last_response within the same api instance" do
          expect { Booking.synchronize(remove: true, query_params: {}) }.not_to raise_error
        end

        it "deletes the booking" do
          expect {
            Booking.synchronize(remove: true, query_params: {})
          }.to change { Booking.where(synced_id: 2).count }.from(1).to(0)
        end
      end
    end

    describe "#perform with remote objects given" do
      context "and only_updated strategy" do
        let!(:booking) { account.bookings.create(synced_id: 42) }

        it "doesn't update synced_all_at" do
          expect{
            Booking.synchronize(remote: [remote_object(id: 42)],
              scope: account)
          }.not_to change { Booking.find_by(synced_id: 42).synced_all_at }
        end
      end
    end

    describe "with SyncedPerScopeTimestampStrategy timestamp strategy" do
      context "with account scope" do
        it "it stores, uses and resets timestamps for given scope" do
          first_sync_time = Time.zone.now.round - 1.hour

          # initial sync
          Timecop.freeze(first_sync_time) do
            expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: nil)).and_return([])
            expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => first_sync_time.to_s } })).twice
            expect {
              account.los_records.synchronize
            }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(nil).to(first_sync_time)
          end

          # second sync using the set timestamps
          second_sync_time = Time.zone.now.round
          Timecop.freeze(second_sync_time) do
            expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: first_sync_time)).and_return([])
            expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => second_sync_time.to_s } })).twice
            expect {
              account.los_records.synchronize
            }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(first_sync_time).to(second_sync_time)
          end

          # reset sync
          expect {
            account.los_records.reset_synced
          }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(second_sync_time).to(nil)

          # new fresh sync without timestamp
          future_sync_time = Time.zone.now.round + 1.hour
          expect(account.api).to receive(:paginate).with("los_records", hash_including(updated_since: nil)).and_return([])
          expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => future_sync_time.to_s } })).twice
          expect {
            account.los_records.synchronize
          }.to change { Synced::Timestamp.with_scope_and_model(account, LosRecord).last_synced_at }.from(nil).to(future_sync_time)
        end
      end

      context "with ENV['LAST_SYNCED_AT_OFFSET'] specified" do
        let(:request_timestamp) { 1.year.ago }

        before do
          ENV["LAST_SYNCED_AT_OFFSET"] = "-60"
          Synced::Timestamp.with_scope_and_model(account, LosRecord).create(synced_at: Time.zone.parse("2010-01-01 12:12:12 UTC"))
          # we defined offset on -60 seconds so query should have updated since equal to 2010-01-01 12:11:12 UTC
          stub_request(:get, "https://www.bookingsync.com/api/v3/los_records?updated_since=2010-01-01%2012:11:12%20UTC").
            to_return(
              status: 200,
              body: { "los_records" => [], "meta" => { "deleted_ids" => [] } }.to_json,
              headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s }
            )
        end

        after do
          ENV.delete("LAST_SYNCED_AT_OFFSET")
        end

        it "synchronizes los by using timestamp changed by amount of seconds defined by LAST_SYNCED_AT_OFFSET" do
          expect(account.api).to receive(:paginate).with(
            "los_records", hash_including(updated_since: Time.zone.parse("2010-01-01 12:11:12 UTC"))
          ).and_call_original
          LosRecord.synchronize(scope: account, remove: true, query_params: {})
        end
      end
    end

    context "with response without request_timestamp" do
      let(:remote_objects) { [remote_object(id: 10, name: "Remote")] }

      it "raises MissingTimestampError" do
        expect(account.api).to receive(:paginate).with("bookings", hash_including(updated_since: nil)).and_return([])
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { } })).twice
        expect {
          Booking.synchronize(scope: account, query_params: {})
        }.to raise_error(Synced::Strategies::UpdatedSince::MissingTimestampError) { |ex|
          msg = "Synchronization failed. API response is missing 'x-updated-since-request-synced-at' header."
          expect(ex.message).to eq msg
        }
      end

      it "prevents from syncing records" do
        expect(account.api).to receive(:paginate).with("bookings", hash_including(updated_since: nil)).and_return(remote_objects)
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { } })).twice
        expect {
          expect {
            Booking.synchronize(scope: account, query_params: {})
          }.to raise_error(Synced::Strategies::UpdatedSince::MissingTimestampError)
        }.not_to change { Booking.count }
      end
    end

    context "transaction per page" do
      context "error is thrown after the first page" do
        around do |example|
          cassette = "synchronize_los_records_updated_since"

          synced_timestamp_strategy_was = LosRecord.synced_timestamp_strategy

          LosRecord.synced_timestamp_strategy = Synced::Strategies::SyncedPerScopeTimestampStrategy

          LosRecordsSyncSetupHelper.with_multipage_sync_crashing_on_second_page(cassette: cassette) do
            example.run
          end

          LosRecord.synced_timestamp_strategy = synced_timestamp_strategy_was
        end

        it "persists the records from the first page but does not update synced_at" do
          expect {
            expect {
              begin
                LosRecord.synchronize(
                  scope: account,
                  strategy: :updated_since,
                  transaction_per_page: true,
                )
              rescue ActiveRecord::RecordInvalid
              end
            }.to change { LosRecord.count }
          }.not_to change { Synced::Timestamp.count }
        end
      end
    end
  end
end
