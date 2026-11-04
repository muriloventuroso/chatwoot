json.array! @comments do |comment|
  json.partial! 'api/v1/models/project_task_comment', formats: [:json], resource: comment
end
