# frozen_string_literal: true

namespace :ommicommail do
  desc "Run all migrations on message databases"
  task migrate_message_databases: :environment do
    Server.all.each do |server|
      puts "Running migrations for #{server.organization.permalink}/#{server.permalink} (ID: #{server.id})"
      server.message_db.provisioner.migrate
    end
  end

  desc "Generate configuration documentation"
  task generate_config_docs: :environment do
    require "konfig/exporters/env_vars_as_markdown"

    FileUtils.mkdir_p("doc/config")
    output = Konfig::Exporters::EnvVarsAsMarkdown.new(OmmicomMail::ConfigSchema).export
    File.write("doc/config/environment-variables.md", output)

    output = OmmicomMail::YamlConfigExporter.new(OmmicomMail::ConfigSchema).export
    File.write("doc/config/yaml.yml", output)
  end

  desc "Generate Helm Environment Variables"
  task generate_helm_env_vars: :environment do
    puts OmmicomMail::HelmConfigExporter.new(OmmicomMail::ConfigSchema).export
  end

  desc "Update the database"
  task update: :environment do
    mysql = ActiveRecord::Base.connection
    if mysql.table_exists?("schema_migrations") &&
       mysql.select_all("select * from schema_migrations").any?
      puts "Database schema is already loaded. Running migrations with db:migrate"
      Rake::Task["db:migrate"].invoke
    else
      puts "No schema migrations exist. Loading schema with db:schema:load"
      Rake::Task["db:schema:load"].invoke
    end
  end
end

namespace :postal do
  task migrate_message_databases: "ommicommail:migrate_message_databases"
  task generate_config_docs: "ommicommail:generate_config_docs"
  task generate_helm_env_vars: "ommicommail:generate_helm_env_vars"
  task update: "ommicommail:update"
end

Rake::Task["db:migrate"].enhance do
  Rake::Task["ommicommail:migrate_message_databases"].invoke
end
