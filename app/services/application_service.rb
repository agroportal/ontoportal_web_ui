class ApplicationService
  # `...` forwards keyword arguments too, which `*args` would turn into a hash
  def self.call(...)
    new(...).call
  end
end