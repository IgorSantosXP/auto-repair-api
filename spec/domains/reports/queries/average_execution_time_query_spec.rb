require "rails_helper"

RSpec.describe Reports::Queries::AverageExecutionTimeQuery do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }

  def create_finished_order(started_at:, finished_at:)
    order = create(:service_order, customer: customer, vehicle: vehicle,
                   status: "finished",
                   execution_started_at: started_at,
                   finished_at: finished_at)
    order
  end

  describe ".call" do
    it "returns zero totals when no finished orders exist" do
      result = described_class.call
      expect(result[:total_orders]).to eq(0)
      expect(result[:average_seconds]).to be_nil
      expect(result[:average_hours]).to be_nil
    end

    it "calculates average execution time across finished orders" do
      create_finished_order(started_at: 8.hours.ago, finished_at: 4.hours.ago)
      create_finished_order(started_at: 6.hours.ago, finished_at: 2.hours.ago)

      result = described_class.call
      expect(result[:total_orders]).to eq(2)
      expect(result[:average_seconds]).to be_within(60).of(4 * 3600)
      expect(result[:average_hours]).to be_within(0.1).of(4.0)
    end

    it "excludes orders without execution_started_at" do
      create(:service_order, customer: customer, vehicle: vehicle,
             status: "finished", execution_started_at: nil, finished_at: 1.hour.ago)
      create_finished_order(started_at: 3.hours.ago, finished_at: 1.hour.ago)

      result = described_class.call
      expect(result[:total_orders]).to eq(1)
    end

    it "filters by from date" do
      create_finished_order(started_at: 10.days.ago, finished_at: 9.days.ago)
      create_finished_order(started_at: 1.hour.ago,  finished_at: 30.minutes.ago)

      result = described_class.call(from: 2.days.ago.to_date)
      expect(result[:total_orders]).to eq(1)
    end

    it "filters by to date" do
      create_finished_order(started_at: 1.hour.ago,  finished_at: 30.minutes.ago)
      create_finished_order(started_at: 10.days.ago, finished_at: 9.days.ago)

      result = described_class.call(to: 8.days.ago.to_date)
      expect(result[:total_orders]).to eq(1)
    end

    it "returns the period in the result" do
      from = 7.days.ago.to_date
      to   = Date.today
      result = described_class.call(from: from, to: to)
      expect(result[:period][:from]).to eq(from)
      expect(result[:period][:to]).to eq(to)
    end
  end
end
