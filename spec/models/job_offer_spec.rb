# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobOffer, type: :model do
  describe "contract_duration" do
    let(:job_offer) do
      build(:job_offer, contract_type: contract_type, contract_duration: contract_duration)
    end

    context "when contrat_type duration = true" do
      let(:contract_type) { create(:contract_type, duration: true) }

      context "with contract_duration" do
        let(:contract_duration) { create(:contract_duration) }

        it "should be valid" do
          expect(job_offer.valid?).to be_truthy
        end
      end

      context "without contract_duration" do
        let(:contract_duration) { nil }

        it "should be invalid" do
          expect(job_offer.valid?).to be_falsey
        end
      end
    end

    context "when contrat_type duration = false" do
      let(:contract_type) { create(:contract_type, duration: false) }

      context "with contract_duration" do
        let(:contract_duration) { create(:contract_duration) }

        it "should be invalid" do
          expect(job_offer.valid?).to be_falsey
        end
      end

      context "without contract_duration" do
        let(:contract_duration) { nil }

        it "should be valid" do
          expect(job_offer.valid?).to be_truthy
        end
      end
    end
  end

  it "should set published_at date when state is published" do
    job_offer = create(:job_offer)
    expect(job_offer.state).to eq("draft")
    expect(job_offer.published_at).to be_nil
    job_offer.publish!
    expect(job_offer.state).to eq("published")
    expect(job_offer.published_at).not_to be_nil
  end

  it "should set archived_at date when state is archived" do
    job_offer = create(:job_offer)
    expect(job_offer.state).to eq("draft")
    expect(job_offer.archived_at).to be_nil
    job_offer.publish!
    job_offer.archive!
    job_offer.reload
    expect(job_offer.state).to eq("archived")
    expect(job_offer.archived_at).not_to be_nil
  end

  it "should set suspended_at date when state is suspended" do
    job_offer = create(:job_offer)
    expect(job_offer.state).to eq("draft")
    expect(job_offer.suspended_at).to be_nil
    job_offer.publish!
    job_offer.suspend!
    job_offer.reload
    expect(job_offer.state).to eq("suspended")
    expect(job_offer.suspended_at).not_to be_nil
  end

  it "should prevent publishing according to organization config" do
    job_offer = create(:job_offer)
    organization = job_offer.organization
    organization.hours_delay_before_publishing = 1
    organization.save

    expect { job_offer.publish! }.to raise_error(AASM::InvalidTransition)
  end

  it "should allow publishing according to organization config" do
    job_offer = create(:job_offer)
    organization = job_offer.organization
    organization.hours_delay_before_publishing = nil
    organization.save

    expect { job_offer.publish! }.to_not raise_error

    job_offer = create(:job_offer)
    organization = job_offer.organization
    organization.hours_delay_before_publishing = 0
    organization.save

    expect { job_offer.publish! }.to_not raise_error
  end

  it "should compute publishing_possible_at" do
    duration = 2
    job_offer = create(:job_offer)
    organization = job_offer.organization
    organization.hours_delay_before_publishing = duration
    organization.save

    expect(job_offer.publishing_possible_at).to eq(job_offer.created_at + duration.hours)
  end

  it "should correctly rebuild timestamp from audit log" do
    job_offer = create(:job_offer)
    job_offer.publish!
    published_at = job_offer.published_at
    expect(published_at).not_to be_nil
    job_offer.archive!
    archived_at = job_offer.archived_at
    expect(archived_at).not_to be_nil

    job_offer.update_columns(archived_at: nil, published_at: nil)
    expect(job_offer.published_at).to be_nil
    expect(job_offer.archived_at).to be_nil

    job_offer.rebuild_published_timestamp!
    job_offer.reload
    expect(job_offer.published_at).not_to be_nil
    time_diff = (published_at - job_offer.published_at).abs
    expect(time_diff).to be_within(1.0).of(1.0)

    job_offer.rebuild_archived_timestamp!
    job_offer.reload
    expect(job_offer.archived_at).not_to be_nil
    time_diff = (published_at - job_offer.published_at).abs
    expect(time_diff).to be_within(1.0).of(1.0)
  end

  it "should correctly find current most advanced job application state" do
    job_offer = create(:job_offer)
    job_applications = create_list(:job_application, 10, job_offer: job_offer)
    expect(job_offer.current_most_advanced_job_applications_state).to eq(0)
    last_state_name, last_state_enum = JobApplication.states.to_a.last
    job_applications.last.send("#{last_state_name}!")
    expect(job_offer.current_most_advanced_job_applications_state).to eq(last_state_enum)
  end

  it "should be visible by owner" do
    employer = create(:employer)
    owner = create(:administrator, role: "employer", employer: employer)
    job_offer = create(:job_offer, owner: owner)
    ability = Ability.new(owner)
    expect(ability.can?(:manage, job_offer)).to be true
  end

  it "should be visible by actors" do
    employer = create(:employer)
    brh = create(:administrator, role: nil, employer: employer)
    other_admin = create(:administrator, role: nil, employer: employer)

    job_offer = create(:job_offer)
    create(:job_offer_actor, role: "brh", administrator: brh, job_offer: job_offer)

    ability = Ability.new(brh)
    expect(ability.can?(:read, job_offer)).to be true

    ability = Ability.new(other_admin)
    expect(ability.can?(:manage, job_offer)).to be false
    expect(ability.can?(:read, job_offer)).to be false
  end

  it "should set identifier correctly even when employer has been changed" do
    job_offer1 = create(:job_offer)
    expect(job_offer1.identifier).to eq "#{job_offer1.employer.code}1"

    job_offer2 = create(:job_offer, employer: job_offer1.employer)
    expect(job_offer2.identifier).to eq "#{job_offer1.employer.code}2"

    job_offer3 = create(:job_offer)
    expect(job_offer3.identifier).to eq "#{job_offer3.employer.code}1"

    job_offer3.employer = job_offer1.employer
    job_offer3.save
    expect(job_offer3.identifier).to eq "#{job_offer1.employer.code}3"
  end

  describe "validate" do
    describe "title" do
      # context 'with ( in title and no F/H at the end' do
      #   let(:job_offer) { build(:job_offer, title: '(') }

      #   it 'is not valid' do
      #     expect(job_offer).to_not be_valid
      #   end
      # end

      # context 'with ( in title and F/H at the end' do
      #   let(:job_offer) { build(:job_offer, title: '( F/H') }

      #   it 'is not valid' do
      #     expect(job_offer).to_not be_valid
      #   end
      # end

      context "without ( in title and with F/H at the end" do
        let(:job_offer) { build(:job_offer, title: "no parenthesis F/H") }

        it "is valid" do
          expect(job_offer).to be_valid
        end
      end
    end

    # describe 'description' do
    #   context 'with description more than 1000 chars' do
    #     let(:job_offer) { build(:job_offer, description: 'desc' * 1000) }

    #     it 'is not valid' do
    #       expect(job_offer).to_not be_valid
    #     end
    #   end

    #   context 'with description less than 1000 chars' do
    #     let(:job_offer) { build(:job_offer, description: 'desc') }

    #     it 'is valid' do
    #       expect(job_offer).to be_valid
    #     end
    #   end
    # end
  end
end
