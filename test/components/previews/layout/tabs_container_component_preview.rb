class Layout::TabsContainerComponentPreview < ViewComponent::Preview


  def default
    render TabsContainerComponent.new do |c|
      sections = ['section 1', 'section 2', 'section 3', 'section 4']

      sections.each do |section_title|
        c.item(title: section_title,
               path: "#{section_title}path",
               selected: section_title.eql?('section 2'),
               page_name: "#{section_title}path")

        c.item_content do
          section_title
        end
      end

    end
  end

  def pill
    render TabsContainerComponent.new(type: 'pill') do |c|
      sections = ['section 1', 'section 2', 'section 3', 'section 4']

      sections.each do |section_title|
        c.item(title: section_title,
               path: "#{section_title}path",
               selected: section_title.eql?('section 2'),
               page_name: "#{section_title}path")

        c.item_content do
          section_title
        end
      end

    end
  end

  def outline
    render TabsContainerComponent.new(type: 'outline') do |c|
      sections = ['section 1', 'section 2', 'section 3', 'section 4']

      sections.each do |section_title|
        c.item(title: section_title,
               path: "#{section_title}path",
               selected: section_title.eql?('section 2'),
               page_name: "#{section_title}path")

        c.item_content do
          section_title
        end
      end

    end
  end

  def with_action_links
    render TabsContainerComponent.new do |c|
      sections = ['section 1', 'section 2', 'section 3', 'section 4']

      sections.each do |section_title|
        c.item(title: section_title,
               path: "#{section_title}path",
               selected: section_title.eql?('section 2'),
               page_name: "#{section_title}path")

        c.item_content do
          section_title
        end
      end
      c.with_pinned_right do
        RoundedButtonComponent.new(icon: 'check.svg').render_in(c) + '<span class="mx-1"></span>'.html_safe + RoundedButtonComponent.new.render_in(c)
      end
    end
  end

end