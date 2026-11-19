# frozen_string_literal: true

class Layout::TableComponentPreview < ViewComponent::Preview

  include ActionView::Helpers::UrlHelper

  def default
    render TableComponent.new do |t|
      table_content(t)
    end
  end

  def stripped
    render TableComponent.new(stripped: true) do |t|
      table_content(t)
    end
  end

  private

  def table_content(t)
    headers = 5.times.map { |i| "header #{i}" }
    rows = 6.times.map { |row| 5.times.map { |i| "line #{row} :#{i} " } }

    t.with_header do |h|
      headers.each do |header|
        h.th { header }
      end
      h.th { 'Action' }
    end

    rows.each do |row|
      t.with_row do |r|
        row.each do |col|
          r.td { col }
        end

        r.td do
          link_to('Edit', '', class: 'mr-3') + link_to('Delete', '')
        end
      end
    end

  end
end
