json.array! @project_members do |member|
  json.partial! 'api/v1/models/project_member', formats: [:json], resource: member
end
