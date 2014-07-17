require "spec_helper"

describe Synced::Engine::Synchronizer do
  let(:account) { Account.create(name: "test") }
  let(:remote_objects) {
    [remote_object(id: 42, name: "Remote", updated_at: "2013-01-01 15:03:01")]
  }

  describe "#perform" do
    context "remote objects are missing in the local db" do
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

    context "remote object exists in the local db" do
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

    context "with option delete_if_missing: true" do
      before do
        Rental.create(name: "Test", synced_id: 15)
        Rental.create(name: "Test", synced_id: 42)
      end

      it "deletes local objects which are missing in the remote objects" do
        expect {
          Rental.synchronize(remote: remote_objects, delete_if_missing: true)
        }.to change { Rental.count }.by(-1)
      end
    end

    describe "runs inside transaction" do
      let(:remote_objects) { [
        remote_object(id: 1, name: "test", updated_at: 2.days.ago),
        remote_object(id: 1, name: "invalid", updated_at: 2.days.ago)
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
      Amenity.synchronize(remote: [remote_object(id: 12, title: "Internet",
        updated_at: "2014-01-17 11:11:11")])
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

    describe "#remote_updated_at" do
      it "returns remote object's updated at" do
        expect(@amenity.remote_updated_at).to eq("2014-01-17 11:11:11")
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
          delete_if_missing: true)
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

    context "with option delete_if_missing: true" do
      let(:location) { Location.create(synced_id: 13) }
      let!(:photo) { location.photos.create(synced_id: 131) }
      let!(:deleted_photo) { location.photos.create(synced_id: 1111) }

      it "removes local association objects if missing in the remote data" do
        Location.synchronize(remote: locations, delete_if_missing: true)
        expect(Photo.find_by(synced_id: 1111)).to be_nil
      end
    end
  end

  describe "#perform on model with disabled synced_data and synced_updated_at" do
    it "synchronizes remote objects correctly" do
      expect {
        Photo.synchronize(remote: [remote_object(id: 17)])
      }.to change { Photo.count }.by(1)
      photo = Photo.last
      expect(photo.synced_id).to eq(17)
      expect(photo).not_to respond_to(:synced_data)
      expect(photo).not_to respond_to(:synced_updated_at)
    end
  end

  describe "synced object" do
    before { Rental.synchronize(remote: remote_objects) }
    let(:rental) { Rental.last }

    it "has synced_updated_at to remote updated at" do
      expect(rental.synced_updated_at).to eq "2013-01-01 15:03:01"
    end

    it "has synced_id to remote object id" do
      expect(rental.synced_id).to eq 42
    end

    it "has synced_data to remote object" do
      expect(rental.synced_data).to eq remote_objects.first
    end
  end
end
