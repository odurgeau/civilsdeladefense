# frozen_string_literal: true

# Generate data structures to be sent through daily summary emails
class DailySummary
  delegate :url_helpers, to: "Rails.application.routes"

  def initialize(day: Date.yesterday)
    @day = day
    @day_begin = @day.beginning_of_day
    @day_end = @day.end_of_day
    @concerned_administrators = []
  end

  def prepare_and_send
    Organization.all.each do |organization|
      prepare(organization)
      send_mail(organization)
    end
  end

  def all_bants
    @all_bants ||= Administrator.where(role: :bant).all
  end

  def prepare(organization)
    prepare_new_job_offers(organization)
    prepare_published_job_offers(organization)
    prepare_new_job_applications(organization)
    prepare_job_applications(organization)

    true
  end

  def send_mail(organization)
    service_name = organization.service_name
    administrators = Administrator.find @concerned_administrators.map(&:uuid)

    @concerned_administrators.each do |concerned_administrator|
      administrator = administrators.detect { |x| x.id == concerned_administrator.uuid }
      data = concerned_administrator.summary_infos
      NotificationsMailer.daily_summary(administrator, data, service_name).deliver
    end
  end

  def prepare_new_job_offers(organization)
    @job_offers = organization.job_offers
      .where(created_at: @day_begin..@day_end)
      .order(created_at: :asc)
      .to_a
    @job_offers.each do |job_offer|
      add_summary_infos_for_job_offer(job_offer, "NewJobOffer")
    end
  end

  def prepare_published_job_offers(organization)
    @job_offers = organization.job_offers
      .where(published_at: @day_begin..@day_end)
      .order(published_at: :asc)
      .to_a
    @job_offers.each do |job_offer|
      add_summary_infos_for_job_offer(job_offer, "PublishedJobOffer")
    end
  end

  def add_summary_infos_for_job_offer(job_offer, kind)
    administrators = build_all_administrators(job_offer)
    administrators.each do |administrator|
      concerned_administrator = @concerned_administrators.detect { |x| x.uuid == administrator.id }
      prexisting = true
      unless concerned_administrator
        prexisting = false
        concerned_administrator = DailySummaryConcernedAdministrator.new(uuid: administrator.id)
      end
      concerned_administrator.add_summary_info(
        title: job_offer.title,
        link: url_helpers.edit_admin_job_offer_url(job_offer),
        kind: kind
      )
      @concerned_administrators << concerned_administrator unless prexisting
    end
  end

  def prepare_new_job_applications(organization)
    query = organization.job_applications.where(created_at: @day_begin..@day_end)
    query = query.includes(:job_offer)
    query = query.order(created_at: :asc).to_a
    @job_applications = query
    @job_applications.each do |job_application|
      add_summary_infos_for_job_application(job_application)
    end
  end

  def add_summary_infos_for_job_application(job_application, new_state = nil)
    job_offer = job_application.job_offer
    administrators = build_administrators(new_state, job_offer)
    administrators.each do |administrator|
      concerned_administrator = @concerned_administrators.detect { |x| x.uuid == administrator.id }
      prexisting = true
      unless concerned_administrator
        prexisting = false
        concerned_administrator = DailySummaryConcernedAdministrator.new(uuid: administrator.id)
      end
      title, kind = build_title_kind(new_state, job_application, job_offer)
      concerned_administrator.add_summary_info(
        title: title,
        link: url_helpers.admin_job_offer_url(job_offer),
        kind: kind
      )
      @concerned_administrators << concerned_administrator unless prexisting
    end
  end

  def prepare_job_applications(organization)
    %w[accepted contract_received affected].each do |state|
      audits = find_job_applications_by_state(state)
      audits.all.each do |element|
        job_application = element.auditable
        if job_application.organization_id == organization.id
          add_summary_infos_for_job_application(job_application, state)
        end
      end
    end
  end

  private

  def find_job_applications_by_state(state)
    r = Audited::Audit.where(auditable_type: "JobApplication")
    r = r.where(created_at: @day_begin..@day_end)
    r = r.where("audited_changes->'state'->1 = ?", state.to_json)
    r = r.order(created_at: :desc)
    r.includes(:auditable)
  end

  protected

  def build_title_kind(state, job_application, job_offer)
    ary = ["#{job_application.user&.full_name || "Compte supprimé"} ##{job_offer.identifier}"]
    ary.push(state.present? ? "#{state.capitalize}JobApplication" : "NewJobApplication")
  end

  def build_administrators(state, job_offer)
    administrators = nil
    if state.nil?
      administrators = job_offer.employer_actors
    else
      administrators = job_offer.grand_employer_actors
      administrators += job_offer.supervisor_employer_actors
      administrators += job_offer.brh_actors
      administrators += all_bants
    end
    administrators.uniq
  end

  def build_all_administrators(job_offer)
    administrators = job_offer.employer_actors
    administrators += job_offer.grand_employer_actors
    administrators += job_offer.supervisor_employer_actors
    administrators += job_offer.brh_actors
    administrators += all_bants
    administrators.uniq
  end
end
