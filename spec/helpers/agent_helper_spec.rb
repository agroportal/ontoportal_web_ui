require 'rails_helper'

# Rails 8.1 parses a leading bracket as part of the key: "[identifiers][0]"
# arrives as params["[identifiers]"], not params["identifiers"]. Agent form
# names must not start with one, even for a top-level agent with no prefix.
RSpec.describe AgentHelper, type: :helper do
  def parsed(name)
    ActionDispatch::Request.new(Rack::MockRequest.env_for("/?#{name}=x")).query_parameters
  end

  it 'names a top-level agent identifier from its own key' do
    name = helper.agent_identifier_name(0, :notation, '')

    expect(name).to eq('identifiers[0][notation]')
    expect(parsed(name)).to eq('identifiers' => { '0' => { 'notation' => 'x' } })
  end

  it 'names a nested affiliation field from its own key' do
    name = helper.agent_field_name(:name, '[affiliations][7]')

    expect(name).to eq('affiliations[7][name]')
    expect(parsed(name)).to eq('affiliations' => { '7' => { 'name' => 'x' } })
  end

  it 'keeps names that already start with a key' do
    expect(helper.agent_field_name(:id, 'agent')).to eq('agent[id]')
  end
end
