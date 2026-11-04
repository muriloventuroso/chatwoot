json.id resource.id
json.project_task_id resource.project_task_id
json.content resource.content
json.author_id resource.author_id
if resource.author.present?
  json.author do
    json.id resource.author.id
    json.name resource.author.name
    json.thumbnail resource.author.avatar_url
  end
else
  json.author nil
end
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
