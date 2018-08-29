require 'rails_helper'

RSpec.describe "admin/settings/categories/index", type: :view do
  before(:each) do
    assign(:categories, [
      create(:category),
      create(:category)
    ])
  end

  it "renders a list of admin/settings/categories" do
    render_template('/admin/settings/inherited_ressources/index')
    # assert_select "tr>td", :text => "Name".to_s, :count => 2
    # assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
