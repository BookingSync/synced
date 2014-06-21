require "spec_helper"

describe Rental do
  it "saves and retrieves synced data" do
    rental = Rental.create(synced_data: { test: "ok" } )
    expect(rental.synced_data.test).to eq 'ok'
  end
end
