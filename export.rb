require 'csv'

# Ecriture du contenu en csv
def write_csv(file_path, headers, lines)
  CSV.open(file_path, "w", {col_sep: ";"}) do |csv|
    csv << headers
    lines.each do |line|
      csv << line
    end
  end
end

# Parcours des lignes à exporter
def generate_offers_employors_array(actors)
  lines = []
  actors.select(:administrator_id, :role).distinct.each do |actor|
    line = []

    administrator = actor.administrator
    line << (administrator.full_name[-1] == ';' ? administrator.full_name[0..-2] : administrator.full_name)
    line << (administrator.email[-1] == ';' ? administrator.email[0..-2] : administrator.email)
    line << I18n.t("activerecord.attributes.job_offer_actor/role.#{actor.role}")

    employer = administrator.employer
    if employer.nil?
      line << ""
      line << ""
      line << ""
      line << ""
    else
      line << employer.name
      line << employer.job_offers.published.count
      line << employer.job_offers.archived.count
      line << employer.job_offers.count
    end

    lines << line
  end

  lines
end

def generate_offers_prefectures_array(offers)
  lines = []

  offers.each do |offer|
    line = []
    
    offer.job_offer_actors.each do |actor|
      line << offer.title
      line << offer.employer.name

      line << JobOfferActor.human_attribute_name("role.#{actor.role}")
      line << actor.administrator.full_name
      line << actor.administrator.email
    end
  
    lines << line
  end

  lines
end

# Export des offres par employeurs avec le nombre d'offres publiées, et archivées
def export_employeurs_offres
  items = JobOfferActor.includes(:administrator)
  headers = %w(actor_name actor_mail actor_role employer_name offers_published offers_archived offers_total)

  puts "Export des offres par employeurs avec le nombre d'offres publiées, et archivées" 
  puts "Nombre d'offres à exporter : #{items.count}" 
  lines = generate_offers_employors_array(items)
  puts "Nombre de lignes à exporter : #{lines.count}" 

  puts "Ecriture du fichier csv" 
  write_csv('export-employers.csv', headers, lines)
end

# Export des offres par prefectures
def export_prefectures_offres
  headers = %w(offer_title employer_name role actor email) 
  items = JobOffer.all

  puts "Export des offres par prefectures" 
  puts "Nombre d'offres à exporter : #{items.count}" 
  lines = generate_offers_prefectures_array(items)
  puts "Nombre de lignes à exporter : #{lines.count}" 

  puts "Ecriture du fichier csv" 
  write_csv('export-prefectures.csv', headers, lines)
end


export_employeurs_offres
export_prefectures_offres