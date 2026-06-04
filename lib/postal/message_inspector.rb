# frozen_string_literal: true

module Postal
  class MessageInspector

    def initialize(config)
      @config = config
    end

    # Inspect a message and update the inspection with the results
    # as appropriate.
    def inspect_message(message, scope, inspection)
    end

    private

    def logger
      OmmicomMail.logger
    end

    class << self

      # Return an array of all inspectors that are available for this
      # installation.
      def inspectors
        [].tap do |inspectors|
          if OmmicomMail::Config.rspamd.enabled?
            inspectors << MessageInspectors::Rspamd.new(OmmicomMail::Config.rspamd)
          elsif OmmicomMail::Config.spamd.enabled?
            inspectors << MessageInspectors::SpamAssassin.new(OmmicomMail::Config.spamd)
          end

          if OmmicomMail::Config.clamav.enabled?
            inspectors << MessageInspectors::Clamav.new(OmmicomMail::Config.clamav)
          end
        end
      end

    end

  end
end
