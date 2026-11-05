# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sidekiq Cron schedule" do
  it "enables cron and configures the schedule file" do
    expect(Sidekiq::Cron.configuration.enabled).to be(true)
    expect(Sidekiq::Cron.configuration.cron_schedule_file).to eq(
      "config/schedule.yml"
    )
  end

  it "loads the overdue reminder schedule" do
    expect(Sidekiq::Cron::Job).to receive(:load_from_hash!)
      .with(
        hash_including(
          "overdue_reminder" => hash_including(
            "class" => "OverdueReminderWorker",
            "cron" => "0 0 * * * Asia/Kolkata",
            "queue" => "default"
          )
        ),
        source: "schedule"
      )

    Sidekiq::Cron::ScheduleLoader.new.load_schedule
  end
end
