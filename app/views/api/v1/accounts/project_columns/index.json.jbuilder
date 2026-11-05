json.array! @project_columns do |column|
  json.partial! 'api/v1/models/project_column', formats: [:json], resource: column
end
