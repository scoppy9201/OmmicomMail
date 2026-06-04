# frozen_string_literal: true

module Postal
  module MessageDB
    module Migrations
      class AddTimeToDeliveries < OmmicomMail::MessageDB::Migration

        def up
          @database.query("ALTER TABLE `#{@database.database_name}`.`deliveries` ADD COLUMN `time` decimal(8,2)")
        end

      end
    end
  end
end
