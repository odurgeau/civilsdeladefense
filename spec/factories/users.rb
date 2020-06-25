# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    organization { Organization.first }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.safe_email }
    password { 'f4k3p455w0rD!' }
    terms_of_service { true }
    certify_majority { true }
    after(:create) do |user|
      user.personal_profile = create(:personal_profile, personal_profileable: user)
    end
  end
end
