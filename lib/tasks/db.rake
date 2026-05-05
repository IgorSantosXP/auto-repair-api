if Rails.env.development?
  Rake::Task["db:migrate"].enhance do
    Rake::Task["db:test:prepare"].invoke
  end
end
