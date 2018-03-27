require "spec_helper"

describe Synced::Strategies::Full do
  let(:account) { Account.create(name: "test") }
  let!(:request_timestamp) { 1.year.ago }
  let(:remote_objects) { [remote_object(id: 42, name: "Remote")] }

  describe "#perform" do
    context "with alias" do
      around do |example|
        VCR.use_cassette("bookings") do
          example.run
        end
      end

      context "without scope" do
        let(:synchronize) { BookingAlias.synchronize }

        it "creates missing remote objects" do
          expect { synchronize }.to change { BookingAlias.count }
        end
      end

      context "with scope" do
        let(:synchronize) { account.booking_aliases.synchronize }

        it "creates missing remote objects" do
          expect { synchronize }.to change { BookingAlias.count }
        end
      end

      context "fetch options" do
        context "with pagination with block" do
          let(:synchronize) do
            account.booking_aliases.synchronize(auto_paginate: false, transaction_per_page: true)
          end

          it "creates missing remote objects" do
            expect { synchronize }.to change { BookingAlias.count }
          end
        end

        context "with auto paginate" do
          let(:synchronize) do
            account.booking_aliases.synchronize(auto_paginate: true, transaction_per_page: false)
          end

          it "creates missing remote objects" do
            expect { synchronize }.to change { BookingAlias.count }
          end
        end

        context "without auto paginate or pagination with block" do
          let(:synchronize) do
            account.booking_aliases.synchronize(auto_paginate: false, transaction_per_page: false)
          end

          it "creates missing remote objects" do
            expect { synchronize }.to change { BookingAlias.count }
          end
        end
      end
    end

    context "with remote: [objects] option (without request to API)" do
      context "and they are missing in the local db" do
        let(:synchronize) { Rental.synchronize(remote: remote_objects) }

        it "creates missing remote objects" do
          expect {
            synchronize
          }.to change { Rental.count }.by 1
        end

        it "returns local synchronized objects" do
          rentals = synchronize
          expect(rentals.size).to eq 1
        end
      end

      context "and they are present in the local db" do
        let(:synchronize) { Rental.synchronize(remote: remote_objects) }
        let!(:rental) { account.rentals.create(synced_data: { id: 42,
          name: "Old Remote" }, synced_id: 42) }

        it "doesn't create another local object" do
          expect { synchronize }.not_to change { Rental.count }
        end

        context "and it's outdated" do
          it "updates existing local object" do
            expect {
              synchronize
            }.to change {
              Rental.last.synced_data.name
            }.from("Old Remote").to("Remote")
          end
        end

        context "and it's not outdated" do
          let(:remote_objects) { [remote_object(id: 42, name: "Old Remote")] }

          it "doesn't update the local object" do
            expect_any_instance_of(Rental).to receive(:save!).never
            synchronize
          end
        end
      end
    end

    context "with remote: nil option" do
      it "performs request on its own" do
        expect_any_instance_of(BookingSync::API::Client).to receive(:paginate)
          .and_return([])
        Location.synchronize(remote: nil)
      end
    end

    describe "removing" do
      context "with remove: true option" do
        before do
          Rental.create(name: "Test", synced_id: 15)
          Rental.create(name: "Test", synced_id: 42)
        end

        it "deletes local objects which are missing in the remote objects" do
          expect {
            Rental.synchronize(remote: remote_objects, remove: true)
          }.to change { Rental.count }.by(-1)
        end

        it "ignores the model default scope" do
          Period.create(start_date: '2014-09-09', end_date: '2014-09-10')
          Period.create(start_date: '2014-09-10', end_date: '2014-09-13')

          Timecop.freeze("2014-09-12 11:11:11 UTC") do
            expect {
              Period.synchronize(remote: [], remove: true)
            }.to change { Period.unscoped.count }.by(-2)
          end
        end
      end

      context "when canceled_at column is present" do
        let(:location) { Location.create(name: "Bahamas") }
        let!(:photo) { Photo.create(synced_id: 12) }
        let!(:photo_to_cancel) { location.photos.create(synced_id: 1) }
        let(:remote_photos) { [remote_object(id: 19, filename: 'a.jpg')] }

        it "cancels local objects" do
          expect {
            Photo.synchronize(remote: remote_photos, scope: location,
              remove: true)
          }.to change { Photo.find_by(synced_id: 1).canceled_at }
        end

        it "cancels only objects within given scope" do
          expect {
            Photo.synchronize(remote: remote_photos, scope: location,
              remove: true)
          }.not_to change { Photo.find_by(synced_id: 12).canceled_at }
        end

        context "when remove: destroy_all is provided" do
          it "destroys instead of canceling" do
            expect {
              Photo.synchronize(remote: remote_photos, scope: location,
                remove: :destroy_all)
            }.to change { Photo.where(synced_id: 1).count }.from(1).to(0)
          end
        end
      end

      context "when remove: true defined in the model" do
        let!(:location) { Location.create(name: "test") }

        it "deletes local objects which are missing in the remote objects" do
          expect {
            Location.synchronize(remote: [])
          }.to change { Location.count }.by(-1)
        end

        context "and overwritten in synchronize method to false" do
          it "doesn't delete local objects which are missing in the remote objects" do
            expect {
              Location.synchronize(remote: [], remove: false)
            }.to_not change { Location.count }
          end
        end
      end

      describe "transactions handling" do
        around do |example|
          LosRecordsSyncSetupHelper.with_multipage_sync_crashing_on_second_page do
            example.run
          end
        end

        describe "without provided :transaction_per_page" do
          before do
            LosRecord.synced_transaction_per_page = nil
          end

          it "does not persist objects on any page if something fails" do
            expect {
              begin
                LosRecord.synchronize(scope: account, strategy: :full)
              rescue ActiveRecord::RecordInvalid
              end
            }.not_to change { LosRecord.count }
          end
        end

         describe "with :transaction_per_page as false" do
          it "does not persist objects on any page if something fails" do
            expect {
              begin
                LosRecord.synchronize(scope: account, transaction_per_page: false, strategy: :full)
              rescue ActiveRecord::RecordInvalid
              end
            }.not_to change { LosRecord.count }
          end
        end

        describe "with :transaction_per_page as true" do
          it "persists objects per page, even if something fails on the next pages" do
            expect {
              begin
                LosRecord.synchronize(scope: account, transaction_per_page: true, strategy: :full)
              rescue ActiveRecord::RecordInvalid
              end
            }.to change { LosRecord.count }
          end
        end
      end
    end

    describe "synchronized object" do
      context "with default synced attributes naming" do
        let(:remote_objects) { [remote_object(id: 42, total: 12345, zip: "12-123")] }
        before do
          Timecop.freeze("2013-01-01 15:03:01 UTC") do
            Rental.synchronize(remote: remote_objects)
          end
        end

        let(:rental) { Rental.last }

        it "has synced_id to remote object id" do
          expect(rental.synced_id).to eq 42
        end

        it "has synced_data to remote object" do
          expect(rental.synced_data).to eq remote_objects.first
        end

        describe "delegated attributes" do
          it "returns value from the hash" do
            expect(rental.total).to eq 12345
          end

          it "works with hash reserved names" do
            expect(rental.zip).to eq "12-123"
          end
        end
      end

      context "with custom synced attributes naming" do
        before(:all) do
          Timecop.freeze("2014-01-17 11:11:11 UTC") do
            Amenity.synchronize(remote: [remote_object(id: 12, title: "Internet",
              updated_at: "2014-01-17 11:11:11")
            ])
          end
          @amenity = Amenity.last
        end

        describe "using custom field #remote_data for synced_data" do
          it "returns synced data" do
            expect(@amenity.remote_data).to eq("id" => 12, "title" => "Internet",
              "updated_at" => "2014-01-17 11:11:11")
          end
        end

        describe "using custom field #remote_id for synced_id" do
          it "returns remote object's ID" do
            expect(@amenity.remote_id).to eq 12
          end
        end
      end
    end

    context "with given scope" do
      it "creates local objects within scope" do
        expect {
          Rental.synchronize(remote: remote_objects, scope: account)
        }.to change { account.rentals.count }.by(1)
      end

      it "deletes local objects within scope" do
        Rental.create(name: "will survive", synced_id: 43)
        account.rentals.create(synced_id: 42)
        expect {
          Rental.synchronize(remote: [], scope: account,
            remove: true)
        }.to change { account.rentals.count }.by(-1)
        expect(Rental.find_by(name: "will survive")).to be_present
      end

      it "returns local synchronized objects within scope" do
        Rental.create
        rentals = Rental.synchronize(remote: remote_objects, scope: account)
        expect(rentals).to eq [Rental.find_by(synced_id: 42)]
      end

      it "ignores the model default scope" do
        rental = Rental.create(synced_id: 43)
        rental.periods.create(start_date: '2014-09-09', end_date: '2014-09-10')
        rental.periods.create(start_date: '2014-09-10', end_date: '2014-09-13')

        remaining_period = Period.create(start_date: '2014-09-09', end_date: '2014-09-10')

        Timecop.freeze("2014-09-12 11:11:11 UTC") do
          expect {
            Period.synchronize(remote: [], scope: rental, remove: true)
          }.to change { Period.unscoped.count }.by(-2)
          expect(Period.unscoped.all).to eq [remaining_period]
        end
      end
    end

    context "with mapping to local attributes" do
      context "passed as an array" do
        it "assigns values from remote to local model's attributes" do
          Amenity.synchronize(remote: [remote_object(id: "test", name: "wow",
            updated_at: Time.now)])
          expect(Amenity.last.name).to eq "wow"
        end

        context "with mapper module" do
          it "uses methods from mapper" do
            Client.synchronize(remote:
              [remote_object(id: 12, name: "Megan Fox")])
            client = Client.last
            expect(client.first_name).to eq "Megan"
            expect(client.last_name).to eq "Fox"
          end
        end
      end

      context "passed as a hash" do
        let(:remote_objects) {
          [remote_object(id: 12, short_name: "foo short name",
            reviews: [remote_object(id: 1), remote_object(id: 2)])]
        }

        it "assigns values from remote to local model's attributes" do
          Booking.synchronize(remote: remote_objects)
          expect(Booking.last.name).to eq "foo short name"
        end

        context "and remote attribute as a lamba" do
          it "assigns result of the block to local model's attribute" do
            Booking.synchronize(remote: remote_objects)
            expect(Booking.last.reviews_count).to eq 2
          end
        end
      end
    end

    context "with mapping to local globalize attributes" do
      let(:remote_objects) { [
        remote_object(id: 12, name: { en: "English name", fr: "French name",
          pl: "Polish name" }, photos: [])
      ] }

      it "creates translations" do
        expect {
          Location.synchronize(remote: remote_objects)
        }.to change { Location::Translation.count }.from(0).to(3)
        location = Location.last
        I18n.with_locale('pl') { expect(location.name).to eq "Polish name" }
        I18n.with_locale('en') { expect(location.name).to eq "English name" }
        I18n.with_locale('fr') { expect(location.name).to eq "French name" }
      end

      context "when a translation is missing in the remote object" do
        let!(:location) do
          Location.create(synced_id: 12, name_translations: {
            en: "English name", fr: "French name", pl: "Polish name" })
        end
        let(:remote_objects) { [
          remote_object(id: 12, name: { en: "English name" }, photos: [])
        ] }

        it "sets them to nil locally" do
          Location.synchronize(remote: remote_objects)
          location = Location.last
          expect(location.translations.find_by_locale('en').name).to eq "English name"
          expect(location.translations.find_by_locale('pl').name).to eq nil
          expect(location.translations.find_by_locale('fr').name).to eq nil
        end
      end
    end

    context "with model associations syncing" do
      let(:locations) { [
        remote_object(id: 13,
          photos: [
            remote_object(id: 131, filename: 'a.jpg'),
            remote_object(id: 133, filename: 'b.jpg')
          ]
        ),
        remote_object(id: 17,
          photos: [
            remote_object(id: 171, filename: 'c.jpg'),
          ]
        )]
      }

      it "creates local objects with associated local objects" do
        expect {
          Location.synchronize(remote: locations)
        }.to change { Location.count }.by(2)
        expect(Location.find_by(synced_id: 13).photos.count).to eq 2
        expect(Location.find_by(synced_id: 17).photos.count).to eq 1
      end

      context "with option remove: true" do
        let(:location) { Location.create(synced_id: 13) }
        let!(:photo) { location.photos.create(synced_id: 131) }
        let!(:deleted_photo) { location.photos.create(synced_id: 1111) }

        it "removes/cancels local association objects if missing in the remote data" do
          Location.synchronize(remote: locations, remove: true)
          expect(Photo.find_by(synced_id: 1111).canceled_at).not_to be_nil
        end
      end
    end

    context "with model without synced_data and synced_all_at columns" do
      it "synchronizes remote objects correctly" do
        expect {
          Photo.synchronize(remote: [remote_object(id: 17)])
        }.to change { Photo.count }.by(1)
        photo = Photo.last
        expect(photo.synced_id).to eq(17)
        expect(photo).not_to respond_to(:synced_data)
        expect(photo).not_to respond_to(:synced_all_at)
      end
    end

    context "without remote: option (makes API request(s))" do
      before do
        allow_any_instance_of(BookingSync::API::Client).to receive(:paginate).and_yield(remote_objects)
      end

      it "makes an api request" do
        expect(account.api).to receive(:paginate).with("rentals",
          { auto_paginate: false }).and_yield(remote_objects)
        expect {
          Rental.synchronize(scope: account)
        }.to change { account.rentals.count }.by(1)
      end

      it "makes an api request with auto_paginate enabled" do
        expect(account.api).to receive(:paginate).with("rentals",
          { auto_paginate: false }).and_yield(remote_objects)
        Rental.synchronize(scope: account)
      end

      it "synchronizes given model" do
        Rental.synchronize(scope: account)
        rental = account.rentals.first
        expect(rental.synced_data).to eq(remote_objects.first)
      end

      it "makes an api request with search params" do
        from = Time.zone.parse("2010-01-01 12:00:00")
        expect(account.api).to receive(:paginate)
          .with("bookings", { auto_paginate: true, from: from, updated_since: nil })
          .and_return(remote_objects)
        expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
        Booking.synchronize(scope: account, query_params: { from: from })
      end

      context "for model with updated since strategy and remove: true" do
        let(:remote_objects) { [remote_object(id: 12, name: "test-12")] }
        let(:account) { Account.create }
        let!(:booking) { account.bookings.create(synced_id: 10, name: "test-10") }

        it "synchronizes given model" do
          expect(account.api).to receive(:paginate).with("bookings",
          { auto_paginate: true, updated_since: nil }).and_return(remote_objects)
          expect(account.api).to receive(:last_response)
            .and_return(double({ meta: { deleted_ids: [] } })).twice
          expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.round.to_s } })).twice
          expect {
            Booking.synchronize(scope: account, remove: true, query_params: {})
          }.to change { account.bookings.count }.by(1)
          expect(Booking.where(synced_all_at: request_timestamp.round).count).to eq(Booking.count)
        end
      end

      context "with associations" do
        let(:api) { double }
        let(:remote_objects) { [
          remote_object(id: 12, photos: [
            remote_object(id: 100, filename: 'b.jpg')])
        ] }

        before do
          allow(Location).to receive(:api).and_return(api)
        end

        it "makes api request with include" do
          expect(api).to receive(:paginate)
            .with("locations", { include: [:photos, :destination, :addresses], auto_paginate: true })
            .and_return(remote_objects)
          Location.synchronize
        end

        it "synchronizes parent model and its associations" do
          allow(api).to receive(:paginate).and_return(remote_objects)
          expect {
            expect {
              Location.synchronize
            }.to change { Location.count }.by(1)
          }.to change { Photo.count }.by(1)
          location = Location.last
          expect(location.synced_id).to eq(12)
          photo = location.photos.first
          expect(photo.synced_id).to eq(100)
          expect(photo.filename).to eq('b.jpg')
        end
      end

      context "with nil has_one association" do
        let(:remote_objects) { [remote_object(id: 12, destination: nil)] }
        let(:api) { Location.api }

        it "does not perform a request to fetch missing association" do
          expect(api).to receive(:paginate).and_return(remote_objects)
          expect {
            Location.synchronize(api: api)
          }.to change { Destination.count }.by(0)
        end
      end

      describe "#api" do
        let(:api) { double }
        let(:location_api) { double }

        context "when client given by api: option" do
          it "uses it" do
            expect(api).to receive(:paginate).with("photos",
              { auto_paginate: true }).and_return([])
            Photo.synchronize(api: api)
          end
        end

        context "when scope responds to api method" do
          it "uses api client from scope" do
            location = Location.create
            allow(location).to receive(:api).and_return(double())
            expect(api).not_to receive(:paginate)
            expect(Location).not_to receive(:api)
            expect(location.api).to receive(:paginate)
              .with("photos", { auto_paginate: true }).and_return([])
            Photo.synchronize(scope: location)
          end
        end

        context "when scope doesn't respond to api but scope class does" do
          it "uses api client from scope class" do
            allow(Location).to receive(:api).and_return(location_api)
            expect(api).not_to receive(:paginate)
            expect(location_api).to receive(:paginate).with("photos",
              { auto_paginate: true }).and_return([])
            Photo.synchronize(scope: Location.create)
          end
        end

        context "when model class responds to api" do
          it "uses api client from model class" do
            expect(api).to receive(:paginate).with("photos", { auto_paginate: true })
              .and_return([])
            expect(Photo).to receive(:api).and_return(api)
            Photo.synchronize
          end
        end

        context "api client can't be found" do
          it "raises Synced::Strategies::Full::MissingAPIClient exception with message" do
            expect {
              Photo.synchronize
            }.to raise_error(Synced::Strategies::Full::MissingAPIClient) { |ex|
              expect(ex.message).to eq "Missing BookingSync API client in Photo class"
            }
          end

          context "when synchronizing with scope" do
            let(:location) { Location.create }
            before { allow(Location).to receive(:api) }

            it "raises Synced::Strategies::Full::MissingAPIClient exception with message" do
              expect {
                Photo.synchronize(scope: location)
              }.to raise_error(Synced::Strategies::Full::MissingAPIClient) { |ex|
                expect(ex.message).to eq %Q{Missing BookingSync API client in #{location} object or Location class when synchronizing Photo model}
              }
            end
          end
        end
      end

      context "and with only updated strategy" do
        let(:remote_objects) { [
          remote_object(id: 1, name: "test1"),
          remote_object(id: 3, name: "test3"),
          remote_object(id: 20, name: "test20")
        ] }
        let!(:booking) { account.bookings.create(name: "test2",
          synced_id: 2, synced_all_at: "2010-01-01 12:12:12") }
        let!(:second_booking) { account.bookings.create(name: "test2",
          synced_id: 200, synced_all_at: "2014-12-12 12:12:12") }
        before do
          allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
            .and_call_original
          stub_request(:get, "https://www.bookingsync.com/api/v3/bookings?updated_since=2010-01-01%2012:12:12%20UTC").
                      to_return(:status => 200, body: {"bookings"=>[{"short_name"=>"one", "id"=>1, "account_id"=>1, "rental_id"=>2, "start_at"=>"2014-04-28T10:55:13Z", "end_at"=>"2014-12-28T10:55:34Z"}], "meta"=>{"deleted_ids"=>[2, 17]}}.to_json, :headers => { "x-updated-since-request-synced-at" => request_timestamp.round.to_s })
        end

        it "makes request to the api with oldest synced_all_at" do
          expect(account.api).to receive(:paginate)
            .with("bookings", { updated_since: Time.zone.parse("2010-01-01 12:12:12"),
              auto_paginate: true }).and_return(remote_objects)
          expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.round.to_s } })).twice
          Booking.synchronize(scope: account, query_params: {})
        end

        context "when remove: true" do
          it "destroys local object by ids from response's meta" do
            expect {
              Booking.synchronize(scope: account, remove: true, query_params: {})
            }.to change { Booking.where(synced_id: 2).count }.from(1).to(0)
          end
        end

        it "updates synced_all_at for all local object within current scope" do
          expect {
            expect {
              Booking.synchronize(scope: account, query_params: {})
            }.to change { Booking.find_by(synced_id: 200).synced_all_at.round }.to(request_timestamp.round)
          }.to change { Booking.find_by(synced_id: 2).synced_all_at.round }.to(request_timestamp.round)
        end
      end

      context "when initial_sync_since given" do
        let(:rental) { Rental.create(name: "test", synced_id: 43) }
        let(:api) { double }

        context "and there are no objects with higher synced_all_at time" do
          it "makes request to the API with initial_sync_since time" do
            expect(rental.api).to receive(:paginate).with("periods", {
              updated_since: Time.zone.parse("2009-04-19 14:44:32"),
              auto_paginate: true }).and_return([])
            expect(rental.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
            Period.synchronize(scope: rental)
          end
        end


        context "and there are objects with higher synced_all_at time" do
          let!(:period) { Period.create(rental: rental,
            synced_all_at: Time.zone.parse("2014-01-01 03:05:06")) }

          it "makes request to the API with minimum synced_all_at time" do
            expect(rental.api).to receive(:paginate).with("periods", {
              updated_since: Time.zone.parse("2014-01-01 03:05:06"),
              auto_paginate: true }).and_return([])
            expect(rental.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.to_s } })).twice
            Period.synchronize(scope: rental)
          end
        end
      end

      context "when include: provided" do
        it "passes include to the API request" do
          expect(account.api).to receive(:paginate)
            .with("bookings", { updated_since: nil, auto_paginate: true,
              include: [:comments, :reviews] })
            .and_return(remote_objects)
          expect(account.api).to receive(:pagination_first_response)
              .and_return(double({ headers: { "x-updated-since-request-synced-at" => request_timestamp.round.to_s } })).twice
          Booking.synchronize(scope: account, include: [:comments, :reviews], query_params: {})
          expect(Booking.where(synced_all_at: request_timestamp.round).count).to eq(Booking.count)
        end

        context "and associations present" do
          let(:remote_objects) { [remote_object(id: 42, photos: [])] }
          let(:api) { double }

          it "adds include and associations to the API request" do
            allow(Location).to receive(:api).and_return(api)
            expect(api).to receive(:paginate)
              .with("locations", { auto_paginate: true,
                include: [:photos, :destination, :comments] })
              .and_return(remote_objects)
            Location.synchronize(include: [:comments])
          end
        end
      end

      context "when include: in model present" do
        let(:api) { double }

        before do
          allow(Client).to receive(:api).and_return(api)
          allow(Location).to receive(:api).and_return(api)
        end

        it "passes include to the API request" do
          expect(api).to receive(:paginate)
            .with("clients", { auto_paginate: false,
              include: [:addresses], fields: [:name] })
            .and_yield(remote_objects)
          Client.synchronize
        end

        context "and associations present" do
          let(:remote_objects) { [remote_object(id: 1, photos: [])] }

          it "adds include from model and associations to the API request" do
            expect(api).to receive(:paginate)
              .with("locations", { auto_paginate: true,
                include: [:photos, :destination, :addresses] })
              .and_return(remote_objects)
            Location.synchronize
          end
        end

        context "and include provided in the synchronize method" do
          it "overwrites include from the model" do
            expect(api).to receive(:paginate)
            .with("clients", { auto_paginate: false,
              include: [:photos], fields: [:name] })
            .and_yield(remote_objects)
            Client.synchronize(include: [:photos])
          end
        end
      end
    end

    context "with fields: option" do
      let(:api) { double }

      before { allow(Client).to receive(:api).and_return(api) }

      it "adds fields to the API request" do
        expect(Client.api).to receive(:paginate)
          .with("clients", { auto_paginate: false,
            include: [:addresses], fields: [:name] })
          .and_yield(remote_objects)
        Client.synchronize
      end

      context "and fields provided in the synchronize method" do
        it "overwrites include from the model" do
          expect(Client.api).to receive(:paginate)
            .with("clients", { auto_paginate: false,
              include: [:addresses], fields: [:phone, :type] })
            .and_yield(remote_objects)
          Client.synchronize(fields: [:phone, :type])
        end
      end
    end

    context "pagination with block transaction" do
      let(:remote_objects_batch1) { [remote_object(id: 42, name: "Remote1")] }
      let(:remote_objects_batch2) { [remote_object(id: 43, name: "Remote2"), remote_object(id: 44, name: "Remote3")] }
      let(:remote_objects_batch3) { [remote_object(id: 45, name: "Remote4")] }

      before do
        allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
          .and_yield(remote_objects_batch1)
          .and_yield(remote_objects_batch2)
          .and_yield(remote_objects_batch3)
      end

      context "all blocks have valid entries" do
        it "persists all entries" do
          expect {
            Rental.synchronize(scope: account, remove: true)
          }.to change { account.rentals.count }.by(4)
          expect(Rental.pluck(:synced_id)).to eq [42, 43, 44, 45]
        end

        it "caches all valid ids, and removes outdated records" do
          account.rentals.create(synced_id: 4)
          expect {
            Rental.synchronize(scope: account, remove: true)
          }.to change { account.rentals.count }.by(3)
          expect(Rental.pluck(:synced_id)).to eq [42, 43, 44, 45]
        end
      end

      context "error thrown in one of blocks" do
        let(:remote_objects_batch2) { [remote_object(id: 43, name: "Remote2"), remote_object(name: "Remote3")] }

        it "doesn't save any entry" do
          expect {
            expect {
              Rental.synchronize(scope: account)
            }.to raise_error(ActiveRecord::RecordInvalid)
          }.not_to change { account.rentals.count }
        end
      end
    end

    context "with handle_processed_objects_proc option" do
      context "and pagination with blocks" do
        let(:remote_objects_batch1) { [remote_object(id: 42, name: "Remote1")] }
        let(:remote_objects_batch2) { [remote_object(id: 45, name: "Remote4")] }

        before do
          allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
            .and_yield(remote_objects_batch1)
            .and_yield(remote_objects_batch2)
        end

        it "calls proc on every batch" do
          Rental.synchronize(scope: account)
          expect(Rental.pluck(:name)).to match_array ["Remote1_modified", "Remote4_modified"]
        end
      end

      context "and auto_paginate" do
        let(:remote_objects) { [remote_object(id: 42, name: "Remote1"), remote_object(id: 45, name: "Remote4")] }

        before do
          allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
            .and_return(remote_objects)
        end

        it "calls proc on all records" do
          Rental.synchronize(scope: account, auto_paginate: true)
          expect(Rental.pluck(:name)).to match_array ["Remote1_modified", "Remote4_modified"]
        end
      end
    end

    describe "returned value" do
      context "with auto_paginate" do
        let(:remote_objects) { [remote_object(id: 42, name: "Remote1"), remote_object(id: 45, name: "Remote2")] }

        before do
          allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
            .and_return(remote_objects)
        end

        it "returns all processed objects" do
          expect(
            Rental.synchronize(scope: account, auto_paginate: true).map(&:synced_id)
          ).to eq [42, 45]
        end
      end

      context "with pagintaion with block" do
        let(:remote_objects_batch1) { [remote_object(id: 42, name: "Remote1")] }
        let(:remote_objects_batch2) { [remote_object(id: 45, name: "Remote4")] }

        before do
          allow_any_instance_of(BookingSync::API::Client).to receive(:paginate)
            .and_yield(remote_objects_batch1)
            .and_yield(remote_objects_batch2)
        end

        it "returns processed objects only from last batch" do
          expect(
            Rental.synchronize(scope: account).map(&:synced_id)
          ).to eq [45]
        end
      end
    end
  end
end
