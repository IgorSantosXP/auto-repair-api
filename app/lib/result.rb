class Result
  attr_reader :payload, :errors, :status

  def initialize(success:, payload: nil, errors: [], status: nil)
    @success = success
    @status = status
    @payload = payload
    @errors = Array(errors)
  end

  def self.success(payload: nil)
    new(success: true, payload: payload)
  end

  def self.failure(errors: [], status: nil)
    new(success: false, errors: errors, status: status)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
