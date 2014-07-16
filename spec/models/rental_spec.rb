require "spec_helper"

describe Rental do
  it "saves and retrieves synced data" do
    rental = Rental.create(synced_data: { test: "ok" } )
    expect(rental.synced_data.test).to eq 'ok'
  end

  describe "#synced_data" do
    it "returns an empty mash" do
      rental = Rental.new
      expect(rental.synced_data).to eq Hashie::Mash.new
    end
  end
end
