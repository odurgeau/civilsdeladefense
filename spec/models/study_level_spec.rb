# frozen_string_literal: true

require "rails_helper"

RSpec.describe StudyLevel, type: :model do
  it { should validate_presence_of(:name) }
end
