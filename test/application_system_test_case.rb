require "test_helper"
require_relative 'helpers/application_test_helpers'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ApplicationTestHelpers::Ontologies
  include ApplicationTestHelpers::Users
  include ApplicationTestHelpers::Users
  include ApplicationTestHelpers::Categories
  include ApplicationTestHelpers::Groups
  include ApplicationTestHelpers::Agents
  include ApplicationTestHelpers::Federation

  driven_by :selenium, using: ENV['CI'].present? ? :headless_chrome : :chrome, screen_size: [1400, 1400], options: {
    browser: :remote,
    url: "http://localhost:4444"
  }

  # How long an element must keep the same box before click_still clicks it,
  # and how long to wait for that
  STILL_FOR_MS = 300
  STILL_TIMEOUT_S = 10

  # Click once the element stops moving. Lazy turbo frames and label chips
  # shift the layout for a second or two after a page or panel loads (the
  # ontology header buttons jump ~150px when the Watch button lands). Selenium
  # sends mousedown and mouseup separately: when the layout shifts in between,
  # the browser fires no click, and the test fails later on a missing page.
  def click_still(selector, **options)
    element = find(selector, **options)
    wait_until_still(element)
    element.click
  end

  def wait_until_still(element)
    using_wait_time(STILL_TIMEOUT_S) do
      page.evaluate_async_script(<<~JS, element, STILL_FOR_MS)
        const [element, stillForMs, done] = arguments
        let box = null
        let since = performance.now()

        const tick = () => {
          const rect = element.getBoundingClientRect()
          const current = [rect.x, rect.y, rect.width, rect.height].join()
          if (current !== box) {
            box = current
            since = performance.now()
          }
          if (performance.now() - since >= stillForMs) {
            return done(true)
          }
          requestAnimationFrame(tick)
        }
        tick()
      JS
    end
  end

  def wait_for(selector, tries = 60)
    tries.times.each do
      puts "waiting for #{selector}"
      break if page.has_selector?(selector)
      sleep 1
    end
  end

  def wait_for_text(text, tries = 60)
    tries.times.each do
      sleep 1
      puts "waiting for #{text}"
      break if page.has_text?(text)
    end
    assert_text text
  end

  def login_in_as(user, admin: false)
    create_user(user, admin: admin)

    visit login_index_url

    # Fill in the login form
    fill_in 'user_username', with: user.username
    fill_in 'user_password', with: user.password

    # Click the login button
    click_button 'Login'
  end

  def assert_date(date)
    assert_text I18n.l(DateTime.parse(date), format: '%B %-d, %Y')
  end

  def search_input(selector, value)
    within "#{selector}" do
      find(".search-inputs .input-field-component").last.set(value)
      page.execute_script("document.querySelector('#{selector} > .search-inputs .input-field-component').dispatchEvent(new Event('input'))")
      sleep 1
      find(".search-inputs .search-content", text: value).click
      sleep 1
      find("input", text: 'Save').click
    end
  end

  def list_checks(selected_values, all_values = [])
    all_values.each do |val|
      uncheck val, allow_label_click: true
    end

    selected_values.each do |val|
      check val, allow_label_click: true
    end
  end

  def list_inputs(parent_selector, selector, values, &block)
    within parent_selector do
      all('.delete').each { |x| x.click }
      find('.add-another-object', text: 'Add another').click
      last_index = values.size - 1
      values.each_with_index do |value, index|
        if value.is_a?(Hash)
          value.each do |key, val|
            all("[name^='#{selector}'][name$='[#{key}]']").last.set(val)
          end
        else
          if block_given?
            block.call(selector, value, index)
          else
            all("[name^='#{selector}']").last.set(value)
          end
        end
        find('.add-another-object', text: 'Add another').click unless index.eql?(last_index)
      end
    end
  end

  def tom_select(selector, values, open_to_add: false)

    multiple = values.is_a?(Array)

    real_select = "[name='#{selector}']"

    ts_wrapper_selector = "#{real_select} + div.ts-wrapper"
    assert_selector ts_wrapper_selector

    # Click on the Tom Select input to open the dropdown
    element = find(ts_wrapper_selector)
    element.click

    return unless page.has_selector?("#{ts_wrapper_selector} > .ts-dropdown")

    if multiple
      # reset the input to empty
      all("#{ts_wrapper_selector} > .ts-control > .item .remove").each do |element|
        element.click
      end
    else
      values = Array(values)
    end

    values.each do |value|
      find("#{ts_wrapper_selector} input").set(value) if open_to_add
      within "#{ts_wrapper_selector} > .ts-dropdown" do
        if page.has_selector?('.option', text: value)
          find('.option', text: value).click
        elsif open_to_add
          find('.create').click
        end
      end
    end

    if multiple
      find("#{ts_wrapper_selector} input").click
    end
  end

  def date_picker_fill_in(selector, value, index = 0)
    page.execute_script("document.querySelectorAll(\"[name^='#{selector}']\")[#{index}].flatpickr().setDate('#{value}')")
  end

  def agent_search(name)
    sleep 2
    wait_for(".search-inputs:last-of-type")
    within(".search-inputs:last-of-type") do
      input = find("input[name^='agent']")
      agent_id = input[:name].split('agent').last
      input.set(name)
      sleep 2
      links = all('a', text: name)
      links_size = links.size
      sleep 1
      first(:link, name).click
      return links_size.eql?(1) ? agent_id : nil
    end

  end

  def agent_fill(agent, parent_id: nil, is_affiliation: false)
    id = agent.id ? "/#{agent.id}" : ''
    form = all("form[action=\"/agents#{id}\"]").first
    within form do
      choose "", option: agent.agentType, allow_label_click: true unless is_affiliation
      fill_in 'name', with: agent.name

      if agent.agentType.eql?('organization')
        refute_selector('input[name="email"]')
        fill_in 'acronym', with: agent.acronym
        fill_in 'homepage', with: agent.homepage
      else
        refute_selector('input[name="acronym"]')
        refute_selector('input[name="homepage"]')
        fill_in 'email', with: agent.email
      end

      identifier = agent.identifiers.first

      if agent.agentType.eql?('organization')
        fill_in "_identifiers_0_notation", with: identifier['notation']
      else
        fill_in "_identifiers_1_notation", with: identifier['notation']
      end

      if is_affiliation || agent.agentType.eql?('organization')
        refute_selector ".agents-affiliations"
        click_on "Save" if agent.agentType.eql?('organization')
        return
      end

      within '.agents-affiliations' do
        all('.delete').each { |x| x.click }
        Array(agent.affiliations).each do |aff|
          aff = OpenStruct.new(aff)
          find('.add-another-object', text: 'Add another').click
          agent_id = agent_search(aff.name)
          id = parent_id && !parent_id.eql?('NEW_RECORD') ? "#{parent_id}_#{agent_id}" : agent_id
          within "turbo-frame[id=\"#{id}\"]" do
            agent_fill(aff, is_affiliation: true)
            sleep 1
          end
        end
      end
      click_on "Save"
    end
  end
end
