class ServiceOrderMailer < ApplicationMailer
  def status_changed
    @order          = params[:order]
    @status         = params[:status] || @order.status
    @approval_link  = params[:approval_link]
    @rejection_link = params[:rejection_link]

    mail(
      to:      @order.customer.email,
      subject: "Service Order #{@order.uuid} — #{@status.humanize}"
    )
  end
end
