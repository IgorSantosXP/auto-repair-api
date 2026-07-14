module ServiceOrders
  module Services
    class CustomerNotifier
      def self.status_changed(order, approval_link: nil, rejection_link: nil)
        return if order.customer&.email.blank?

        ServiceOrderMailer
          .with(order: order, status: order.status,
                approval_link: approval_link, rejection_link: rejection_link)
          .status_changed
          .deliver_later
      end
    end
  end
end
