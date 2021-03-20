class AddUsefulInformationToJobOffer < ActiveRecord::Migration[6.1]
  def change
    add_column :job_offers, "useful_informations", :string
  end
end
