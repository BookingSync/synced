require "spec_helper"

describe Synced::Strategies::Check do
  let(:account) { Account.create }
  let(:remote_rental) { remote_object(id: 42, name: "apartment") }
  let!(:rental) { account.rentals.create(synced_data: { id: 42,
    name: "apartment" }, synced_id: 42) }
  let(:remote_rentals) { [remote_rental] }

  before do
    allow(account.api).to receive(:paginate).with("rentals",
      { auto_paginate: true }).and_return(remote_rentals)
  end

  it "returns hash with differences" do
    differences = Rental.synchronize(scope: account, strategy: :check)
    expect(differences.missing).not_to be_nil
    expect(differences.additional).not_to be_nil
    expect(differences.changed).not_to be_nil
  end

  context "when object is missing in the local database" do
    let(:remote_rentals) { [remote_rental, remote_object(id: 15, name: "small one")] }

    it "returns missing objects" do
      differences = Rental.synchronize(scope: account, strategy: :check)
      expect(differences.missing).to eq([{"id" => 15, "name" => "small one"}])
      expect(differences.additional).to be_empty
      expect(differences.changed).to be_empty
    end
  end

  context "when local objects are not present in the API response" do
    let!(:trashed_rental) { account.rentals.create(synced_data: { id: 10,
      name: "trashed apartment" }, synced_id: 10) }

    it "returns additional objects" do
      differences = Rental.synchronize(scope: account, strategy: :check)
      expect(differences.additional).to eq([trashed_rental])
      expect(differences.missing).to be_empty
      expect(differences.changed).to be_empty
    end
  end

  context "when local object is outdated" do
    before do
      rental.update_attributes(synced_data: { id: 42, name: "apartment Updated!" })
    end

    it "returns changed objects" do
      differences = Rental.synchronize(scope: account, strategy: :check)
      expect(differences.changed).to eq([{ "synced_data" =>
        ["{\"id\":42,\"name\":\"apartment Updated!\"}", { "id"=>42, "name"=>"apartment" }] }])
      expect(differences.missing).to be_empty
      expect(differences.additional).to be_empty
    end
  end

  describe Synced::Strategies::Check::Result do
    describe "#passed?" do
      context "when local objects are in sync with remote ones" do
        it "returns true" do
          expect(Synced::Strategies::Check::Result.new).to be_passed
        end
      end

      context "when local objects are not in sync with remote ones" do
        it "returns false" do
          [:missing, :additional, :changed].each do |kind|
            result = Synced::Strategies::Check::Result.new
            result.send("#{kind}=", [double])
            expect(result).not_to be_passed
          end
        end
      end
    end

    describe "#model_class" do
      it "returns synced model class" do
        result = Synced::Strategies::Check::Result.new(Rental)
        expect(result.model_class).to eq Rental
      end
    end

    describe "to_s" do
      require "synced/result_presenter"
      before { rental.destroy }

      it "returns formatted result" do
        result = Rental.synchronize(scope: account, strategy: :check)
out = %Q{
synced_class:     Rental
options:          #{result.options}
changed count:    0
additional count: 0
missing count:    1
changed:          []
additional:       []
missing:          [#<Hashie::Mash id=42 name="apartment">]
}
        expect(result.to_s).to eq out
      end
    end
  end
end