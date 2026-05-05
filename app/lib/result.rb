class Result
  attr_reader :payload, :errors

  def initialize(success:, payload: nil, errors: [])
    @success = success
    @payload = payload
    @errors = Array(errors)
  end

  def self.success(payload: nil)
    new(success: true, payload: payload)
  end

  def self.failure(errors: [])
    new(success: false, errors: errors)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
