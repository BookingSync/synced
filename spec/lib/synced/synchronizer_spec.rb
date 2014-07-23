require "spec_helper"

describe Synced::Synchronizer do
  let(:account) { Account.create(name: "test") }
  let(:remote_objects) { [remote_object(id: 42, name: "Remote")] }

  describe "#perform with remote objects given" do
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

      it "doesn't set synced_all_at" do
        synchronize
        rental = Rental.find_by(synced_id: 42)
        expect(rental.synced_all_at).to be_nil
      end
    end

    context "and they are present in the local db" do
      let(:synchronize) { Rental.synchronize(remote: remote_objects) }
      let!(:rental) { account.rentals.create(synced_data: { id: 42,
        name: "Old Remote" }, synced_id: 42,
        synced_all_at: "2014-01-17 11:11:11 UTC") }

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

      it "doesn't change synced_all_at" do
        expect {
          synchronize
        }.not_to change { Rental.find_by(synced_id: 42).synced_all_at }
      end
    end

    context "with option remove: true" do
      before do
        Rental.create(name: "Test", synced_id: 15)
        Rental.create(name: "Test", synced_id: 42)
      end

      it "deletes local objects which are missing in the remote objects" do
        expect {
          Rental.synchronize(remote: remote_objects, remove: true)
        }.to change { Rental.count }.by(-1)
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
    end

    describe "runs inside transaction" do
      let(:remote_objects) { [
        remote_object(id: 1, name: "test"),
        remote_object(id: 1, name: "invalid")
      ] }

      it "and doesn't save anything if saving one record fails" do
        expect {
          expect {
            Amenity.synchronize(remote: remote_objects)
          }.to raise_error(ActiveRecord::RecordInvalid)
        }.not_to change { Amenity.count }
      end
    end
  end

  describe "#perform with custom attributes" do
    before(:all) do
      Timecop.freeze("2014-01-17 11:11:11 UTC") do
        Amenity.synchronize(remote: [
          remote_object(id: 12, title: "Internet",
            updated_at: "2014-01-17 11:11:11")
        ])
      end
      @amenity = Amenity.last
    end

    describe "#remote_data" do
      it "returns remote object's data" do
        expect(@amenity.remote_data).to eq("id" => 12, "title" => "Internet",
          "updated_at" => "2014-01-17 11:11:11")
      end
    end

    describe "#remote_id" do
      it "returns remote object's ID" do
        expect(@amenity.remote_id).to eq 12
      end
    end
  end

  describe "#perform with given scope" do
    it "creates local objects within scope" do
      expect {
        Rental.synchronize(remote: remote_objects, scope: account)
      }.to change { account.rentals.count }.by(1)
    end

    it "deletes local objects within scope" do
      Rental.create(name: "will survive")
      account.rentals.create
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
  end

  describe "#perform to local attributes" do
    context "passed as an array" do
      it "assigns values from remote to local model's attributes" do
        Amenity.synchronize(remote: [remote_object(id: "test", name: "wow",
          updated_at: Time.now)])
        expect(Amenity.last.name).to eq "wow"
      end
    end
  end

  context "#perform on model with associations" do
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

  describe "#perform on model with disabled synced_data and synced_all_at" do
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

  describe "#perform without remote objects given" do
    before do
      allow_any_instance_of(BookingSync::API::Client).to receive(:get)
        .and_return(remote_objects)
    end

    it "makes an api request" do
      expect(account.api).to receive(:get).with("rentals",
        { auto_paginate: true }).and_return(remote_objects)
      expect {
        Rental.synchronize(scope: account)
      }.to change { account.rentals.count }.by(1)
    end

    it "make an api request with auto_paginate enabled" do
      expect(account.api).to receive(:get).with("rentals",
        { auto_paginate: true }).and_return(remote_objects)
      Rental.synchronize(scope: account)
    end

    it "synchronizes given model" do
      Rental.synchronize(scope: account)
      rental = account.rentals.first
      expect(rental.synced_data).to eq(remote_objects.first)
    end

    context "with associations" do
      let(:remote_objects) { [
        remote_object(id: 12, photos: [
          remote_object(id: 100, filename: 'b.jpg')])
      ] }

      it "makes api request with include" do
        expect(Location.api).to receive(:get)
          .with("locations", { include: [:photos], auto_paginate: true })
          .and_return(remote_objects)
        Location.synchronize
      end

      it "synchronizes parent model and its associations" do
        allow(Location.api).to receive(:get).and_return(remote_objects)
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

    describe "#api" do
      let(:api) { double() }

      context "when scope responds to api method" do
        it "uses api client from scope" do
          location = Location.create
          allow(location).to receive(:api).and_return(double())
          expect(api).not_to receive(:get)
          expect(Location).not_to receive(:api)
          expect(location.api).to receive(:get)
            .with("photos", { auto_paginate: true }).and_return([])
          Photo.synchronize(scope: location)
        end
      end

      context "when scope doesn't respond to api but scope class does" do
        it "uses api client from scope class" do
          expect(api).not_to receive(:get)
          expect(Location.api).to receive(:get).with("photos",
            { auto_paginate: true }).and_return([])
          Photo.synchronize(scope: Location.create)
        end
      end

      context "when model class responds to api" do
        it "uses api client from model class" do
          expect(api).to receive(:get).with("photos", { auto_paginate: true })
            .and_return([])
          expect(Photo).to receive(:api).and_return(api)
          Photo.synchronize
        end
      end

      context "api client can't be found" do
        it "raises an exception" do
          expect {
            Photo.synchronize
          }.to raise_error(Synced::Synchronizer::MissingAPIClient) { |ex|
            expect(ex.message).to eq "Missing BookingSync API client in Photo class"
          }
        end
      end
    end

    context "and with only updated strategy" do
      let(:remote_objects) {[
        remote_object(id: 1, name: "test1"),
        remote_object(id: 3, name: "test3"),
        remote_object(id: 20, name: "test20")
      ]}
      let!(:booking) { account.bookings.create(name: "test2",
        synced_id: 2, synced_all_at: "2010-01-01 12:12:12") }
      let!(:second_booking) { account.bookings.create(name: "test2",
        synced_id: 200, synced_all_at: "2014-12-12 12:12:12") }
      before do
        allow(account.api).to receive(:get).and_return(remote_objects)
        allow(account.api).to receive(:last_response)
          .and_return(Hashie::Mash.new(meta: {deleted_ids: [2, 17]}))
      end

      it "makes request to the api with oldest synced_all_at" do
        expect(account.api).to receive(:get)
          .with("bookings", { updated_since: "2010-01-01 12:12:12",
            auto_paginate: true }).and_return(remote_objects)
        Booking.synchronize(scope: account)
      end

      context "when remove: true" do
        it "destroys local object by ids from response's meta" do
          expect {
            Booking.synchronize(scope: account, remove: true)
          }.to change { Booking.where(synced_id: 2).count }.from(1).to(0)
        end
      end

      it "updates synced_all_at for all local object within current scope" do
        expect {
          expect {
            Booking.synchronize(scope: account)
          }.to change { Booking.find_by(synced_id: 200).synced_all_at }
        }.to change { Booking.find_by(synced_id: 2).synced_all_at }
      end
    end

    context "when include: provided" do
      it "passes include to the API request" do
        expect(account.api).to receive(:get)
          .with("bookings", { updated_since: nil, auto_paginate: true,
            include: [:comments, :reviews] })
          .and_return(remote_objects)
        Booking.synchronize(scope: account, include: [:comments, :reviews])
      end

      context "and associations present" do
        let(:remote_objects) { [remote_object(id: 42, photos: [])] }
        it "adds include and associations to the API request" do
          expect(Location.api).to receive(:get)
            .with("locations", { auto_paginate: true,
              include: [:photos, :comments] })
            .and_return(remote_objects)
          Location.synchronize(include: [:comments])
        end
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

  describe "synced object" do
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
  end
end
