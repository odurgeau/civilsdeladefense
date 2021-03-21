namespace :vta do
  desc "Envoi le rapport des éléments mis à jour"
  task :daily_summary => :environment do
    DailySummary.new(day: 1.day.ago).prepare_and_send
  end

  desc "Récupère les messages de la boite mail"
  task :fetch_inbound_mesage => :environment do
    InboundMessage.fetch_and_process
  end

  # ENV["NBR_DAYS_INACTIVITY_PERIOD_BEFORE_DELETION"]
  # ENV["NBR_DAYS_NOTICE_PERIOD_BEFORE_DELETION"]
  desc "Nettoie les comptes utilisateurs trop ancien"
  task :clean_users_too_old => :environment do
    User.destroy_when_too_old
  end
end
