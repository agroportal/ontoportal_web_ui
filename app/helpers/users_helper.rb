module UsersHelper
  def user_hidden_fields(f, user, extras = [])
    fields = [
      :firstName, :lastName, :username, :email, :orcidId, :githubId
    ]
    
    html_fields = fields.map { |field| f.hidden_field field, value: user.send(field) }
    html_fields << f.hidden_field(:admin, value: (user.admin? ? 1 : 0))
    
    extras.each do |extra|
      html_fields << f.hidden_field(extra, value: user.send(extra))
    end
    
    safe_join(html_fields, "\n")
  end
end
