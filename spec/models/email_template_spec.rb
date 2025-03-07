# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailTemplate, type: :model do
  it { should validate_presence_of(:title) }
  it { should validate_presence_of(:subject) }
  it { should validate_presence_of(:body) }
end
