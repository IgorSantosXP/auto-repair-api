module ServiceOrders
  module Services
    class CustomerNotifier
      # Budget and payment e-mails are sent by the Billing Service.
      SILENT_STATUSES = %w[awaiting_approval awaiting_payment].freeze

      def self.status_changed(order)
        return if order.customer&.email.blank?
        return if SILENT_STATUSES.include?(order.status)

        ServiceOrderMailer.with(order: order, status: order.status).status_changed.deliver_now
      rescue StandardError => e
        Rails.logger.warn("[CustomerNotifier] Failed to e-mail order #{order.uuid}: #{e.class}: #{e.message}")
        false
      end
    end
  end
end
