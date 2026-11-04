json.array! @project_tasks do |task|
  json.partial! 'api/v1/models/project_task', formats: [:json], resource: task
end
