# frozen_string_literal: true

class Admin::JobOffersController < Admin::BaseController
  before_action :set_job_offers, only: %i[index archived]
  layout :choose_layout

  include JobOfferStateActions
  include JobOfferStatisticsActions

  # GET /admin/job_offers
  # GET /admin/job_offers.json
  def index
    respond_to do |format|
      format.html do
        @job_offers_unfiltered = action_name == "index" ? @job_offers_active : @job_offers_archived
        job_offers_nearly_filtered = @job_offers_unfiltered
        if params[:s].present?
          job_offers_nearly_filtered = job_offers_nearly_filtered.search_full_text(params[:s])
            .unscope(:order)
        end
        @q = job_offers_nearly_filtered.ransack(params[:q])
        @job_offers_filtered = @q.result(distinct: true).page(params[:page]).per_page(20)
        render action: :index
      end
      format.js do
        render action: :index
      end
    end
  end

  alias_method :archived, :index

  # GET /admin/job_offers/1
  # GET /admin/job_offers/1.json
  def show
  end

  # GET /admin/job_offers/1/board
  # GET /admin/job_offers/1/board.json
  def board
    @job_applications = @job_offer.job_applications.group_by(&:state)
    request.xhr? && render(layout: false)
  end

  def add_actor
    job_offer_id = params[:job_offer_id]
    @job_offer = job_offer_id.present? ? JobOffer.find(job_offer_id) : JobOffer.new
    @administrator = find_attach_or_build_administrator
    @administrator.organization = current_organization
    if @administrator.valid?
      render action: "add_actor", layout: false
    else
      render json: @administrator.errors, status: :unprocessable_entity
    end
  end

  # GET /admin/job_offers/new
  def new
    @job_offer = JobOffer.new_from_source(params[:job_offer_id])
    @job_offer ||= JobOffer.new_from_scratch(current_administrator)
    @job_offer.employer = current_administrator.employer unless current_administrator.bant?
    @job_offer.organization = current_organization
  end

  # GET /admin/job_offers/1/edit
  def edit
  end

  # POST /admin/job_offers
  # POST /admin/job_offers.json
  def create
    @job_offer.owner = current_administrator
    @job_offer.organization = current_organization
    @job_offer.employer = current_administrator.employer unless current_administrator.bant?
    @job_offer.cleanup_actor_administrator_dep(current_administrator, current_organization)

    respond_to do |format|
      if @job_offer.save
        format.html { redirect_to %i[admin job_offers], notice: t(".success") }
        format.json { render :show, status: :created, location: @job_offer }
      else
        format.html { render :new }
        format.json { render json: @job_offer.errors, status: :unprocessable_entity }
      end
    end
  end

  alias_method :create_and_draftize, :create

  # PATCH/PUT /admin/job_offers/1
  # PATCH/PUT /admin/job_offers/1.json
  def update
    @job_offer.assign_attributes(job_offer_params)
    @job_offer.cleanup_actor_administrator_dep(current_administrator, current_organization)

    respond_to do |format|
      if @job_offer.save
        format.html { redirect_to %i[admin job_offers], notice: t(".success") }
        format.json { render :show, status: :ok, location: @job_offer }
      else
        format.html { render :edit }
        format.json { render json: @job_offer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/job_offers/1
  # DELETE /admin/job_offers/1.json
  def destroy
    @job_offer.destroy
    respond_to do |format|
      format.html { redirect_to job_offers_url, notice: t(".success") }
      format.json { head :no_content }
    end
  end

  protected

  def choose_layout
    return "admin" if @job_offer&.new_record?

    %w[new edit].include?(action_name) ? "admin" : "admin/job_offer_single"
  end

  private

  def set_job_offers
    @employers = Employer.all
    @job_offers_active = @job_offers.admin_index_active
    @job_offers_archived = @job_offers.admin_index_archived
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_job_offer
    redirect_to [:admin, @job_offer], status: :moved_permanently if params[:id] != @job_offer.slug
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def job_offer_params
    params.require(:job_offer).permit(permitted_fields)
  end

  def permitted_fields
    fields = %i[title description category_id professional_category_id employer_id required_profile
      recruitment_process contract_type_id contract_duration_id contract_start_on
      is_remote_possible available_immediately study_level_id experience_level_id bop_id
      sector_id estimate_monthly_salary_net estimate_annual_salary_gross benefit_id
      location city county county_code country_code postcode region]
    job_offer_actors_attributes = %i[id role _destroy]
    job_offer_actors_attributes << {administrator_attributes: %i[id email _destroy]}
    fields << {job_offer_actors_attributes: job_offer_actors_attributes}
  end

  def find_attach_or_build_administrator
    existing_administrator = Administrator.find_by(email: params[:email].downcase)
    root_object = @job_offer.job_offer_actors.build(role: params[:role])
    admin = root_object.administrator = existing_administrator if existing_administrator
    admin ||= root_object.build_administrator(email: params[:email])
    admin.inviter ||= current_administrator
    admin
  end
end
