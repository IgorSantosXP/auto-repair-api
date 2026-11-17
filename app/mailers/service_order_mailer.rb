class ServiceOrderMailer < ApplicationMailer
  def status_changed
    @order  = params[:order]
    @status = params[:status] || @order.status

    mail(
      to:      @order.customer.email,
      subject: "Service Order #{@order.uuid} — #{@status.humanize}"
    )
  end
end
