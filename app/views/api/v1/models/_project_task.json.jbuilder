json.id resource.id
json.account_id resource.account_id
json.project_id resource.project_id
json.parent_task_id resource.parent_task_id
json.title resource.title
json.description resource.description
json.status resource.status
json.priority resource.priority
json.assignee_id resource.assignee_id
if resource.assignee.present?
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.name
    json.thumbnail resource.assignee.avatar_url
  end
else
  json.assignee nil
end
json.creator_id resource.creator_id
json.due_date resource.due_date
json.position resource.position
json.completed_at resource.completed_at&.to_i
json.subtasks_count resource.subtasks_count
json.completed_subtasks_count resource.completed_subtasks_count
json.comments_count resource.comments_count
json.attachments resource.attachments do |attachment|
  json.id attachment.id
  json.filename attachment.filename.to_s
  json.file_type attachment.content_type
  json.byte_size attachment.byte_size
  json.file_url url_for(attachment)
end
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i

if local_assigns[:detailed]
  json.subtasks resource.subtasks.ordered do |subtask|
    json.partial! 'api/v1/models/project_task', formats: [:json], resource: subtask
  end
end
